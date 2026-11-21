import Scroller2d
import SpriteKit
import UIKit

/// Runs DesertRuins gameplay on Scroller2d's scene base and consumes its exported level models.
///
/// Scroller2d API usage in this type is called out with `Scroller2d API:` comments.
@MainActor
final class GameScene: AppSharedSceneBase {
    // The SDK retains its delegates. A weak forwarder avoids retaining the scene.
    @MainActor
    private final class SceneHooks: @preconcurrency SceneBaseCustomDelegate,
                                    @preconcurrency SceneBaseContactDelegate {
        weak var scene: GameScene?

        /// Keeps a non-owning link back to the game scene for Scroller2d lifecycle callbacks.
        init(_ scene: GameScene) { self.scene = scene }

        /// Forwards Scroller2d's scene-presentation callback to game startup.
        func didMoveScene(to view: SKView) { scene?.startScene() }
        /// Forwards Scroller2d's per-frame callback to gameplay simulation.
        func updateScene(_ time: TimeInterval) { scene?.step(time) }
        /// Forwards Scroller2d's post-physics callback to camera and bounds cleanup.
        func didFinishSceneUpdate() { scene?.finishFrame() }
        /// Forwards contacts reported by Scroller2d's scene base to gameplay handling.
        func didBeginContact(_ contact: SKPhysicsContact) { scene?.handleContact(contact) }
        /// Required Scroller2d contact hook; this game has no contact-end behavior.
        func didEndContact(_ contact: SKPhysicsContact) {}
        /// Required Scroller2d hook; this demo does not use named editor callbacks.
        func manageSceneCallbacks(action: callbackType, function: String, object: Any?) {}
    }

    private enum Body {
        static let player: UInt32 = 1
        static let solid: UInt32 = 2
        static let checkpoint: UInt32 = 4
        static let coin: UInt32 = 8
        static let hazard: UInt32 = 16
        static let enemy = collisionTypes.enemyTouch.rawValue
        static let relic: UInt32 = 64
    }

    private enum Control { case left, right, jump, slash, restart, sound }
    private enum Pose: String { case idle, run, jump, slash }
    private struct BackgroundLayer {
        let tiles: [SKSpriteNode]
        let speed: CGFloat
    }

    private let data: LevelData
    private var world = SKNode()
    private var cameraFollow: CameraFollowHelper?
    private var frameDelta: TimeInterval = 0
    private let lens = SKCameraNode()
    private let hud = SKNode()
    private let ending = SKNode()
    private var replayButton: SKShapeNode?
    private var runStarted: TimeInterval?
    private var relics = 0
    private let status = SKLabelNode(fontNamed: "Menlo-Bold")
    private let counter = SKLabelNode(fontNamed: "Menlo-Bold")
    private var buttons: [Control: SKShapeNode] = [:]
    private var keys: Set<UIKeyboardHIDUsage> = []
    private var held: [ObjectIdentifier: Control] = [:]
    private var backdrop: [BackgroundLayer] = []
    private var surfaces: [CGRect] = []
    private var endX: CGFloat = 0
    private var player: SKSpriteNode!
    private var guardian: SKSpriteNodeEnemy2dBase?
    private var beacon: SKSpriteNode?
    private var beaconFrames: [SKTexture] = []
    private var poses: [Pose: [SKTexture]] = [:]
    private var timings: [Pose: TimeInterval] = [:]
    private var pose: Pose?
    private var start = CGPoint.zero
    private var respawn = CGPoint.zero
    private var attackSound: GameSound?
    private var hitSound: GameSound?
    private var coins = 0
    private var coinTotal = 0
    private var checkpointReached = false
    private var won = false
    private var nextJump: TimeInterval = -.infinity
    private var slashUntil: TimeInterval = -.infinity
    private var slashHitAt: TimeInterval?
    private var pendingRespawn = false
    private var clock: TimeInterval = 0
    private var deaths = 0
    private let playerBodySize = CGSize(width: 30, height: 69)
    private let playerBodyCenter = CGPoint(x: 0, y: -7)
    private let runSpeed: CGFloat = 282
    #if DEBUG
    private let smokeTest = ProcessInfo.processInfo.arguments.contains("--verify-gameplay")
    private var testStage = 0
    private var testStart: TimeInterval?
    private var testDirection: CGFloat = 0
    #endif

    /// Creates the Scroller2d-based scene, attaches SDK delegates, and builds exported level data.
    init(data: LevelData) throws {
        self.data = data
        // Scroller2d API: initialize `AppSharedSceneBase`, which forwards lifecycle and contact events.
        super.init(size: data.sceneSize)
        scaleMode = .aspectFit
        anchorPoint = data.level.settings.anchorPoint?.toCGPoint() ?? CGPoint(x: 0.5, y: 0.5)
        backgroundColor = SKColor(red: 0.23, green: 0.17, blue: 0.29, alpha: 1)
        addChild(world)
        addChild(lens)
        camera = lens
        lens.addChild(hud)
        hud.zPosition = 500
        let hooks = SceneHooks(self)
        // Scroller2d API: install adapters for the SDK's lifecycle and physics-contact delegates.
        customDelegate = hooks
        contactDelegate = hooks
        makeHUD()
        try build()
    }

    /// Prevents storyboard decoding because the scene requires validated `LevelData`.
    required init?(coder: NSCoder) { fatalError("Use init(data:)") }

    /// Configures physics and starts music after Scroller2d reports that the scene is presented.
    private func startScene() {
        physicsWorld.gravity = CGVector(dx: 0, dy: -13)
        data.play(data.level.background?.soundEffects?.first { $0.soundType == "background" }, looping: true)
    }

    /// Clears runtime state and rebuilds the playable scene from Scroller2d level models.
    private func build() throws {
        world.removeAllChildren()
        ending.removeFromParent()
        ending.removeAllChildren()
        hud.isHidden = false
        replayButton = nil
        runStarted = nil
        relics = 0
        for layer in backdrop { layer.tiles.forEach { $0.removeFromParent() } }
        backdrop.removeAll()
        surfaces.removeAll()
        held.removeAll()
        keys.removeAll()
        pose = nil
        coins = 0
        coinTotal = 0
        deaths = 0
        checkpointReached = false
        won = false
        pendingRespawn = false
        guardian = nil
        beacon = nil
        for layer in data.level.background?.backgrounds ?? [] where layer.isVisible != false {
            guard let image = layer.image else { continue }
            let tiles = try (0..<3).map { _ in
                try data.sprite(image, in: "Backgrounds", size: size, at: .zero, z: layer.zPosition ?? 1)
            }
            tiles.forEach { lens.addChild($0) }
            backdrop.append(BackgroundLayer(tiles: tiles, speed: layer.speed ?? 0))
        }

        try buildPlayer()
        // Scroller2d API: resolve catalog overrides and assemble terrain and SDK nodes.
        let assembly = try LevelAssemblyHelper.build(
            resources: data.resources,
            scene: self,
            groundTexture: { try self.data.texture($0, in: "Ground") },
            groundCategoryBitMask: Body.solid,
            groundCollisionBitMask: Body.player,
            groundCollisionTopInset: 2,
            target: player,
            configureObstacle: { try self.configureObstacle(&$0) },
            createCharacter: { entry, character, root, _ in
                guard entry.charClassType == "enemy" else { return nil }
                return try self.buildGuardian(entry, character: character, parent: root)
            }
        )
        player.removeFromParent()
        world.removeFromParent()
        world = assembly.root
        world.addChild(player)
        assembly.install(in: self)
        // Keep the complete course and touch HUD visible on different aspect ratios.
        scaleMode = .aspectFit
        surfaces = assembly.ground.surfaces
        endX = assembly.ground.endPoint.x
        configureObstacleNodes(assembly.obstacles)
        cameraFollow = CameraFollowHelper(
            camera: lens, target: player, viewportSize: size,
            bounds: CGRect(x: -size.width * anchorPoint.x, y: -size.height * anchorPoint.y,
                           width: endX + size.width * anchorPoint.x, height: size.height)
        )
        cameraFollow?.lookAhead = CGVector(dx: 90, dy: 0)
        try buildPickups()
        placePlayer(at: start)
        respawn = start
        lens.position = .zero
        refreshCamera()
        updateCounter()
        show("DESERT RUINS  •  REACH THE RELIC")
        NSLog("DESERTRUINS_LEVEL_READY ground=%d coins=%d checkpoint=%@ guardian=%@",
              surfaces.count, coinTotal, beacon == nil ? "missing" : "loaded", guardian == nil ? "missing" : "loaded")
    }

    /// Applies asset naming and forgiving collision sizes after the API resolves defaults.
    private func configureObstacle(_ obstacle: inout Obstacle) throws {
        guard let image = obstacle.image else { throw LevelError.invalid(obstacle.name ?? "Obstacle") }
        obstacle.image = data.catalogName(image, in: "Obstacles")
        obstacle.usePhysics = obstacle.usePhysics ?? false
        obstacle.useGravity = obstacle.useGravity ?? false
        obstacle.isDynamic = obstacle.isDynamic ?? false
        let size = dimensions(obstacle.devices)
        guard size.width > 0, size.height > 0 else { throw LevelError.invalid(image) }
        let solid = obstacle.elementName == "trail_crate"
        let hitbox = CGSize(width: size.width * (solid ? 0.85 : 0.76),
                            height: size.height * (solid ? 0.88 : 0.76))
        if obstacle.usePhysics == true, obstacle.physics == nil {
            var physics = PhysicsProperty()
            physics.rectangles = [RectanglePhysics(size: hitbox.toString())]
            obstacle.physics = physics
        }
    }

    /// Assigns the game's contact rules to nodes already constructed by the API.
    private func configureObstacleNodes(_ nodes: [SKSpriteNode2dBase]) {
        for node in nodes {
            node.isUserInteractionEnabled = false
            node.texture?.filteringMode = .nearest
            let solid = (data.level.obstacles ?? []).contains {
                $0.elementName == "trail_crate" && node.name?.hasPrefix("OBJECT_\($0.name)_") == true
            }
            if let body = node.physicsBody {
                body.categoryBitMask = solid ? Body.solid : Body.hazard
                body.collisionBitMask = solid ? Body.player : 0
                body.contactTestBitMask = 0
                body.friction = 0
                if solid {
                    let size = CGSize(width: node.size.width * 0.85, height: node.size.height * 0.88)
                    surfaces.append(CGRect(x: node.position.x - size.width / 2,
                                           y: node.position.y - size.height / 2,
                                           width: size.width, height: size.height))
                }
            }
        }
    }

    /// Creates the player from Scroller2d character data and then builds its enemy.
    private func buildPlayer() throws {
        let entries = data.level.characters?.filter { $0.isVisible != false } ?? []
        guard let entry = entries.first(where: { $0.elementName == "dune_explorer" }) else {
            throw LevelError.invalid("Explorer start")
        }
        let character = try data.resources.character(for: entry)
        let device = character.devices
        let position = point(device)
        let offset = point(device, .offset)
        let spriteSize = dimensions(device)
        let actions = character.actions
        let animation = character.animation?.waitPerAnimationFrame
        guard let image = character.image else { throw LevelError.invalid(entry.name) }
        poses = [
            .idle: try data.animation(image, in: "Characters", scene: self),
            .run: try data.animation("\(entry.elementName)_\(actions?.move ?? "Running")", in: "Characters", scene: self),
            .jump: try data.animation("\(entry.elementName)_Jumping", in: "Characters", scene: self),
            .slash: try data.animation("\(entry.elementName)_\(actions?.attack ?? "Slash")", in: "Characters", scene: self)
        ]
        timings = [.idle: animation?.idle ?? 0.17, .run: animation?.move ?? 0.08,
                   .jump: 0.09, .slash: animation?.attack ?? 0.07]
        start = CGPoint(x: position.x + offset.x, y: position.y + offset.y)
        guard let idleTexture = poses[.idle]?.first else { throw LevelError.invalid(entry.name) }
        player = SKSpriteNode2dBase(texture: idleTexture, name: entry.name,
                                   position: start, size: spriteSize, anchorPoint: CGPoint(x: 0.5, y: 0.5),
                                   zPosition: entry.zPosition, gameScene: self)
        player.isUserInteractionEnabled = false
        let sounds = character.soundEffects
        attackSound = sounds?.first { $0.soundType == "attack" }
        hitSound = sounds?.first { $0.soundType == "touch" }
        installBody(on: player, size: playerBodySize, center: playerBodyCenter, category: Body.player)
        world.addChild(player)

    }

    /// Uses Scroller2d's character helper to create the configured enemy AI node.
    private func buildGuardian(_ entry: CharacterLevelItem, character resolved: Character,
                               parent: SKNode) throws -> SKSpriteNodeEnemy2dBase {
        var character = resolved
        character.image = data.catalogName(entry.elementName, in: "Characters")
        character.actions = character.actions ?? Actions(idle: "Idle")
        character.actions?.initial = nil // The guardian starts in the SDK's idle state.
        let idle = character.actions?.idle ?? "Idle"
        let atlas = "\(character.image ?? "")_\(idle)"
        guard !SKTextureAtlas(named: atlas).textureNames.isEmpty else {
            throw LevelError.missing("Guardian sprite atlas \(atlas)")
        }
        let frames = try data.animation("\(entry.elementName)_\(idle)", in: "Characters", scene: self)

        // The enemy helper rebuilds its contact shape on animation changes.
        let shape = PolyPhysics(direction: "both", points:
            ["{-15,-41.5}", "{15,-41.5}", "{15,27.5}", "{-15,27.5}"].map { Scroller2d.Point(point: $0) },
            action: "idle")
        var physics = character.physics ?? PhysicsProperty()
        if physics.polygons == nil { physics.polygons = [shape] }
        character.physics = physics
        var masks = character.collisionMasks ?? CollisionDetection()
        masks.category = "enemyTouch"
        character.collisionMasks = masks

        // Scroller2d API: create the enemy node and its configured movement/animation behavior.
        var resolvedEntry = entry
        resolvedEntry.properties = nil
        let node = CreateCharacterHelper(levelItem: resolvedEntry, element: character, target: player,
                                         node: parent, scene: self)
        node.texture = frames[0]
        node.isUserInteractionEnabled = false
        node.xScale = -1
        guardian = node
        return node
    }

    /// Creates checkpoints, coins, and artifacts from Scroller2d level collections.
    private func buildPickups() throws {
        for item in data.level.checkpoints?.locations ?? [] where item.isVisible != false {
            let base = object(item.elementName)
            guard let image = item.image ?? data.level.checkpoints?.image ?? base?.image, !image.isEmpty else {
                throw LevelError.invalid("Checkpoint image")
            }
            let spriteSize = dimensions(item.devices, fallback: dimensions(base?.devices))
            var position = point(item.devices)
            let offset = point(item.devices, .offset)
            position.x += offset.x
            if item.useGravity ?? base?.useGravity ?? true {
                position.y = determineGroundBaseY(x: position.x)
                position.y += spriteSize.height/2
            }
            position.y += offset.y
            let frames = try data.animation(image, in: "Checkpoints", scene: self)
            let node = SKSpriteNode(texture: frames[0], size: spriteSize)
            node.position = position
            node.zPosition = item.zPosition
            beaconFrames = frames
            installBody(on: node, size: CGSize(width: 20, height: spriteSize.height), category: Body.checkpoint)
            beacon = node
            world.addChild(node)
        }
        for item in data.level.coins?.coins ?? [] {
            let base = object(item.elementName)
            guard let image = item.image ?? base?.image else { throw LevelError.invalid("Coin image") }
            let spriteSize = dimensions(item.devices, fallback: dimensions(base?.devices))
            let node = try data.sprite(image, in: "Coins", size: spriteSize, at: point(item.devices),
                                       z: item.zPosition ?? 120)
            installBody(on: node, size: spriteSize, category: Body.coin)
            world.addChild(node)
            coinTotal += 1
        }
        for item in data.level.artifacts?.artifacts ?? [] {
            let base = object(item.elementName)
            guard let image = item.image ?? base?.image else { throw LevelError.invalid("Relic image") }
            let spriteSize = dimensions(item.devices, fallback: dimensions(base?.devices))
            let node = try data.sprite(image, in: "Artifacts", size: spriteSize, at: point(item.devices),
                                       z: item.zPosition ?? 120)
            node.alpha = item.alpha ?? 1
            installBody(on: node, size: spriteSize, category: Body.relic)
            world.addChild(node)
        }
    }

    /// Finds Scroller2d object-catalog defaults for a placed level element.
    private func object(_ name: String?) -> GenericObject? {
        data.objects.first { $0.elementName == name }
    }

    /// Installs a Scroller2d or SpriteKit body and configures its collision masks.
    private func installBody(on node: SKNode, size: CGSize, center: CGPoint = .zero, category: UInt32) {
        let body: SKPhysicsBody
        if let sprite = node as? SKSpriteNodeSharedBase {
            // Scroller2d API: shared sprite nodes provide the SDK physics-body convenience method.
            sprite.addPhysics(rectangle: size, center: center, categoryBitMask: category)
            guard let configured = sprite.physicsBody else { return }
            body = configured
        } else {
            body = SKPhysicsBody(rectangleOf: size, center: center)
        }
        body.isDynamic = category == Body.player
        body.affectedByGravity = body.isDynamic
        body.allowsRotation = false
        body.friction = 0
        body.restitution = 0
        body.linearDamping = 0
        body.categoryBitMask = category
        body.collisionBitMask = category == Body.player ? Body.solid : category == Body.solid ? Body.player : 0
        body.contactTestBitMask = category == Body.player
            ? Body.checkpoint | Body.coin | Body.hazard | Body.enemy | Body.relic : 0
        body.usesPreciseCollisionDetection = category == Body.player
        node.physicsBody = body
    }

    /// Reports whether the player's feet rest on an assembled terrain surface.
    private var grounded: Bool {
        let feet = player.position.y + playerBodyCenter.y - playerBodySize.height/2
        return abs(player.physicsBody?.velocity.dy ?? 0) < 40 && surfaces.contains {
            player.position.x + playerBodySize.width/2 > $0.minX
                && player.position.x - playerBodySize.width/2 < $0.maxX
                && abs(feet - $0.maxY) < 7
        }
    }

    /// Advances movement, respawning, combat, enemy AI, and animation for one frame.
    private func step(_ time: TimeInterval) {
        frameDelta = clock == 0 ? 0 : max(0, min(time - clock, 1.0 / 15))
        clock = time
        if runStarted == nil { runStarted = time }
        guard let body = player.physicsBody else { return }
        #if DEBUG
        if smokeTest { verifyGameplay(at: time) }
        #endif
        if pendingRespawn || player.position.y < -size.height * 0.7 {
            pendingRespawn = false
            deaths += 1
            placePlayer(at: respawn)
            show(checkpointReached ? "RESPAWNED AT THE BEACON" : "TRY AGAIN")
        }
        let right = held.values.contains(.right) || keys.contains(.keyboardRightArrow) || keys.contains(.keyboardD)
        let left = held.values.contains(.left) || keys.contains(.keyboardLeftArrow) || keys.contains(.keyboardA)
        var direction: CGFloat = (right ? 1 : 0) - (left ? 1 : 0)
        #if DEBUG
        if smokeTest { direction = testDirection }
        #endif
        if won { direction = 0 }
        body.velocity.dx = direction * runSpeed
        if direction != 0 { player.xScale = direction }
        if !won, nextJump >= clock, grounded {
            body.velocity.dy = 665
            nextJump = -.infinity
        }
        if let hit = slashHitAt, clock >= hit {
            slashHitAt = nil
            if let enemy = guardian {
                let dx = (enemy.position.x-player.position.x) * player.xScale
                if (-12...88).contains(dx), abs(enemy.position.y-player.position.y) < 62 {
                    enemy.physicsBody = nil
                    enemy.removeAllActions()
                    enemy.run(.sequence([.fadeOut(withDuration: 0.18), .removeFromParent()]))
                    guardian = nil
                    data.play(hitSound)
                }
            }
        }
        if !won { guardian?.update() }
        setPose(clock < slashUntil ? .slash : !grounded ? .jump : direction == 0 ? .idle : .run)
    }

    /// Constrains the player to level bounds and updates the camera after physics.
    private func finishFrame() {
        let left = -size.width * anchorPoint.x + playerBodySize.width/2
        let right = max(left, endX-playerBodySize.width/2)
        player.position.x = min(right, max(left, player.position.x))
        refreshCamera()
    }

    /// Follows the player and scrolls parallax tiles at their exported speeds.
    private func refreshCamera() {
        // Scroller2d API: follow and constrain the camera after physics.
        cameraFollow?.viewportSize = size
        cameraFollow?.update(deltaTime: frameDelta)
        for layer in backdrop {
            let shift = (lens.position.x*layer.speed).truncatingRemainder(dividingBy: size.width)
            for (index, tile) in layer.tiles.enumerated() {
                tile.position.x = CGFloat(index-1)*size.width - shift
            }
        }
    }

    /// Moves the player to a spawn point and clears transient movement and attack state.
    private func placePlayer(at position: CGPoint) {
        player.position = position
        player.physicsBody?.velocity = .zero
        nextJump = -.infinity
        slashUntil = -.infinity
        slashHitAt = nil
    }

    /// Changes player pose using Scroller2d's `manualAnimate` action helper.
    private func setPose(_ next: Pose) {
        guard pose != next, let frames = poses[next], let first = frames.first else { return }
        pose = next
        player.removeAction(forKey: "pose")
        player.texture = first
        let frequency: animationFrequency = next == .idle || next == .run ? .foreverAutomatically : .once
        // Scroller2d API: build an SDK animation action with its frequency and frame timing model.
        let action = SKAction.manualAnimate(frames: frames, skScene: self, frameRange: nil,
                                            idlePerFrameWait: timings[next] ?? 0.1, frequency: frequency)
        player.run(action, withKey: "pose")
    }

    /// Buffers a jump briefly so the next grounded simulation step can apply it.
    private func jump() { nextJump = clock + 0.14 }

    /// Starts a slash animation and schedules damage to match the visible swing.
    private func slash() {
        guard clock >= slashUntil, !won else { return }
        slashUntil = clock + Double(poses[.slash]?.count ?? 6) * (timings[.slash] ?? 0.07)
        slashHitAt = clock + 0.095
        data.play(attackSound)
    }

    /// Applies checkpoint, pickup, hazard, enemy, and relic contact results.
    private func handleContact(_ contact: SKPhysicsContact) {
        let other = contact.bodyA.categoryBitMask == Body.player ? contact.bodyB : contact.bodyA
        guard let node = other.node, !won, !pendingRespawn else { return }
        switch other.categoryBitMask {
        case Body.checkpoint:
            guard !checkpointReached, node === beacon else { return }
            checkpointReached = true
            let foot = determineGroundBaseY(x: node.position.x)
            respawn = CGPoint(x: node.position.x-8, y: foot-playerBodyCenter.y+playerBodySize.height/2+2)
            node.physicsBody = nil
            if !beaconFrames.isEmpty {
                let requested = data.level.checkpoints?.animateFromImage ?? 0
                let first = min(max(requested, 0), beaconFrames.count-1)
                node.run(.manualAnimate(frames: beaconFrames, skScene: self,
                                        frameRange: first..<beaconFrames.count,
                                        idlePerFrameWait: 0.11, frequency: .once))
            }
            data.play(data.level.checkpoints?.soundEffects?.first)
            updateCounter()
            show("CHECKPOINT SAVED")
        case Body.coin:
            node.removeFromParent()
            coins += 1
            updateCounter()
        case Body.hazard, Body.enemy:
            #if DEBUG
            if smokeTest {
                NSLog("DESERTRUINS_TEST_CONTACT %@ x=%.1f y=%.1f", node.name ?? "guardian",
                      player.position.x, player.position.y)
            }
            #endif
            pendingRespawn = true
            data.play(hitSound)
        case Body.relic:
            node.removeFromParent()
            relics += 1
            finishLevel()
        default: break
        }
    }

    /// Builds the results card from Scroller2d's exported level-end configuration.
    private func finishLevel() {
        won = true
        releaseControls()
        player.physicsBody?.velocity.dx = 0

        guard let config = data.level.levelEnd,
              let items = config.windowItems, !items.isEmpty else {
            show("RELIC RECOVERED  •  TAP RESET TO PLAY AGAIN", persistent: true)
            return
        }

        let shade = SKSpriteNode(color: SKColor(white: 0.04, alpha: 0.72), size: size)
        ending.zPosition = max(hud.zPosition + 1, config.zPosition ?? 600)
        ending.addChild(shade)

        let card = SKNode()
        card.position = config.windowOffset?.toCGPoint() ?? .zero
        card.zPosition = 1
        ending.addChild(card)

        let elapsed = Int(max(0, clock - (runStarted ?? clock)))
        let time = String(format: "%d:%02d", elapsed / 60, elapsed % 60)
        let gold = SKColor(red: 1, green: 0.79, blue: 0.55, alpha: 1)
        for item in items {
            let position = point(item.devices)
            let offset = point(item.devices, .offset)
            let origin = CGPoint(x: position.x + offset.x, y: position.y + offset.y)
            switch windowItemType.from(string: item.type) {
            case .window:
                let size = dimensions(item.devices, fallback: CGSize(width: 530, height: 270))
                let panel = SKShapeNode(rectOf: size, cornerRadius: 20)
                panel.fillColor = SKColor(red: 0.16, green: 0.11, blue: 0.23, alpha: 1)
                panel.strokeColor = gold
                panel.lineWidth = 2
                panel.position = origin
                panel.zPosition = item.zPosition
                card.addChild(panel)
            case .title, .description:
                let label = resultLabel(item, text: item.text ?? "", color: gold)
                label.position = origin
                card.addChild(label)
            case .coinCount, .timeCount, .artifactCount:
                let value: String
                switch item.type {
                case "coinCount": value = "\(coins)/\(coinTotal)"
                case "timeCount": value = time
                default: value = "\(relics)"
                }
                let caption = resultLabel(item, text: item.text ?? "", color: gold)
                caption.position = CGPoint(x: origin.x, y: origin.y + 13)
                card.addChild(caption)
                let result = resultLabel(item, text: value, color: .white)
                result.fontSize = 27
                result.position = CGPoint(x: origin.x, y: origin.y - 16)
                card.addChild(result)
            case .replay:
                let size = dimensions(item.devices, fallback: CGSize(width: 190, height: 44))
                let button = SKShapeNode(rectOf: size, cornerRadius: 12)
                button.fillColor = gold
                button.strokeColor = .clear
                button.position = origin
                button.zPosition = item.zPosition
                button.addChild(resultLabel(item, text: item.text ?? "PLAY AGAIN",
                                            color: SKColor(red: 0.16, green: 0.11, blue: 0.23, alpha: 1)))
                card.addChild(button)
                replayButton = button
            default:
                continue
            }
        }
        hud.isHidden = true
        lens.addChild(ending)
        data.play(config.soundEffects?.first { $0.soundType == "onDemand" })
    }

    /// Creates a styled label from a Scroller2d level-end window item.
    private func resultLabel(_ item: WindowItem, text: String, color: SKColor) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: item.fontInfo?.fontName ?? "Menlo-Bold")
        label.text = text
        label.fontSize = item.fontInfo?.fontSize ?? 18
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.zPosition = item.zPosition
        return label
    }

    /// Creates status labels and touch controls fixed to the camera.
    private func makeHUD() {
        /// Applies shared HUD styling and attaches the label to the overlay.
        func label(_ node: SKLabelNode, size: CGFloat, position: CGPoint) {
            node.fontSize = size
            node.fontColor = SKColor(red: 1, green: 0.91, blue: 0.73, alpha: 1)
            node.position = position
            hud.addChild(node)
        }
        label(status, size: 18, position: CGPoint(x: 0, y: size.height/2-61))
        label(counter, size: 14, position: CGPoint(x: 0, y: size.height/2-27))
        let edge = size.width/2
        let bottom = -size.height/2+49
        addButton(.left, "◀", at: CGPoint(x: -edge+51, y: bottom))
        addButton(.right, "▶", at: CGPoint(x: -edge+138, y: bottom))
        addButton(.jump, "JUMP", at: CGPoint(x: edge-143, y: bottom))
        addButton(.slash, "SLASH", at: CGPoint(x: edge-52, y: bottom))
        addButton(.restart, "RESET", at: CGPoint(x: edge-49, y: size.height/2-29), compact: true)
        addButton(.sound, "SOUND", at: CGPoint(x: -edge+49, y: size.height/2-29), compact: true)
    }

    /// Creates one touch-control button and records the control it represents.
    private func addButton(_ control: Control, _ title: String, at position: CGPoint, compact: Bool = false) {
        let box = SKShapeNode(rectOf: CGSize(width: compact ? 82 : 78, height: compact ? 40 : 72),
                              cornerRadius: compact ? 12 : 21)
        box.position = position
        box.lineWidth = 1.5
        box.strokeColor = SKColor(red: 1, green: 0.79, blue: 0.58, alpha: 0.72)
        box.fillColor = SKColor(red: 0.17, green: 0.12, blue: 0.24, alpha: 0.84)
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = title
        label.fontSize = compact ? 12 : 16
        label.verticalAlignmentMode = .center
        label.fontColor = .white
        box.addChild(label)
        hud.addChild(box)
        buttons[control] = box
    }

    /// Displays a status message, optionally fading it after a short delay.
    private func show(_ message: String, persistent: Bool = false) {
        status.removeAllActions()
        status.alpha = 1
        status.text = message
        if !persistent { status.run(.sequence([.wait(forDuration: 2.4), .fadeOut(withDuration: 0.35)])) }
    }

    /// Refreshes the HUD with current coin and checkpoint progress.
    private func updateCounter() {
        counter.text = "COINS \(coins)/\(coinTotal)   •   BEACON \(checkpointReached ? "LIT" : "UNLIT")"
    }

    /// Hit-tests a touch against the camera-attached control buttons.
    private func control(for touch: UITouch) -> Control? {
        let point = touch.location(in: hud)
        return buttons.first { $0.value.frame.contains(point) }?.key
    }

    /// Starts touch controls or activates replay on the results screen.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if ending.parent != nil {
            if let replayButton, let panel = replayButton.parent,
               touches.contains(where: { replayButton.frame.contains($0.location(in: panel)) }) {
                reset()
            }
            return
        }
        for touch in touches {
            guard let input = control(for: touch) else { continue }
            switch input {
            case .left, .right: held[ObjectIdentifier(touch)] = input
            case .jump: jump()
            case .slash: slash()
            case .restart: reset()
            case .sound: toggleSound()
            }
        }
    }

    /// Transfers or releases direction as a finger moves between buttons.
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            if let next = control(for: touch), next == .left || next == .right {
                held[id] = next
            } else {
                held.removeValue(forKey: id)
            }
        }
    }

    /// Releases directional controls associated with ended touches.
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { held.removeValue(forKey: ObjectIdentifier($0)) }
    }

    /// Releases cancelled touches through the normal ending path.
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    /// Rebuilds the scene from the already-loaded Scroller2d data models.
    private func reset() {
        do { try build() } catch { show(error.localizedDescription, persistent: true) }
    }

    /// Toggles audio and updates the sound button caption.
    private func toggleSound() {
        data.muted.toggle()
        (buttons[.sound]?.children.first as? SKLabelNode)?.text = data.muted ? "MUTED" : "SOUND"
    }

    /// Maps supported hardware keys to controls and reports whether each was consumed.
    func key(_ usage: UIKeyboardHIDUsage, pressed: Bool) -> Bool {
        switch usage {
        case .keyboardLeftArrow, .keyboardRightArrow, .keyboardA, .keyboardD,
             .keyboardSpacebar, .keyboardJ, .keyboardR, .keyboardM:
            if pressed {
                guard keys.insert(usage).inserted else { return true }
                switch usage {
                case .keyboardSpacebar: jump()
                case .keyboardJ: slash()
                case .keyboardR: reset()
                case .keyboardM: toggleSound()
                default: break
                }
            } else {
                keys.remove(usage)
            }
            return true
        default: return false
        }
    }

    /// Stops frame updates, input, actions, and audio when the simulator scene disconnects.
    func stopDemo() {
        isPaused = true
        releaseControls()
        removeAllActions()
        world.removeAllActions()
        data.stopAudio()
    }

    /// Clears held touch and keyboard movement when input focus is lost.
    func releaseControls() {
        keys.removeAll()
        held.removeAll()
    }

    #if DEBUG
    // Runs the course using the same movement, jump, collision, and slash code as touch input.
    /// Advances the automated gameplay smoke test and logs completion or timeout.
    private func verifyGameplay(at time: TimeInterval) {
        if testStart == nil { testStart = time }
        guard testStage < 8, time-(testStart ?? time) < 16 else {
            if testStage < 8 {
                NSLog("DESERTRUINS_SMOKE_FAILED stage=%d x=%.1f y=%.1f deaths=%d", testStage,
                      player.position.x, player.position.y, deaths)
                testStage = 8
                testDirection = 0
            }
            return
        }
        switch testStage {
        case 0:
            testDirection = 1
            if player.position.x >= -145, grounded { jump(); testStage = 1 }
        case 1:
            if checkpointReached { testStage = 2 }
        case 2:
            if player.position.x > 172 { testDirection = 0 }
            if deaths == 1 && abs(player.position.x-respawn.x) < 24 { testStage = 3 }
        case 3:
            testDirection = 1
            if player.position.x >= 111, grounded { jump(); testStage = 4 }
        case 4:
            if player.position.x >= 423, grounded { jump(); testStage = 5 }
        case 5:
            if player.position.x >= 595 { slash(); testStage = 6 }
        case 6:
            if guardian == nil, player.position.x >= 688, grounded { jump(); testStage = 7 }
        case 7:
            if won, deaths == 1, ending.parent != nil, replayButton != nil, relics == 1 {
                NSLog("DESERTRUINS_SMOKE_PASSED checkpoint=lit deaths=%d coins=%d guardian=defeated relic=recovered levelEnd=shown replay=available", deaths, coins)
                testStage = 8
                testDirection = 0
            }
        default: break
        }
    }
    #endif
}
