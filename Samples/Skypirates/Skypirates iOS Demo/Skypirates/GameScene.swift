// Copyright (c) 2026 Cool Monkey LLC
// SPDX-License-Identifier: MIT
// Demo Swift source only; see ../LICENSE.

import SpriteKit
import UIKit
import Scroller2d

/// A free-roaming sample. World coordinates remain stable: the camera makes scenery
/// scroll opposite to flight on both axes. No horizontal terrain assembly is required.
@MainActor
final class GameScene: AppSharedSceneBase {
    @MainActor private final class Hooks: @preconcurrency SceneBaseCustomDelegate, @preconcurrency SceneBaseContactDelegate {
        weak var game: GameScene?
        init(_ game: GameScene) { self.game = game }
        func didMoveScene(to view: SKView) { game?.lastTime = nil }
        func updateScene(_ time: TimeInterval) { game?.step(time) }
        func didFinishSceneUpdate() { game?.finishFrame() }
        func didBeginContact(_ contact: SKPhysicsContact) { game?.contact(contact) }
        func didEndContact(_ contact: SKPhysicsContact) {}
        func manageSceneCallbacks(action: callbackType, function: String, object: Any?) {}
    }
    private enum Mask {
        static let player: UInt32 = 1, enemy: UInt32 = 2, friendlyShot: UInt32 = 4, enemyShot: UInt32 = 8
    }
    private final class Enemy {
        let node: SKSpriteNode2dBase
        let ship: Bool
        var health: Int
        var cooldown: TimeInterval
        init(_ node: SKSpriteNode2dBase, ship: Bool, delay: TimeInterval) {
            self.node = node; self.ship = ship; health = ship ? 5 : 2; cooldown = delay
        }
    }
    private struct Shot { let node: SKSpriteNode; var age: TimeInterval = 0 }
    private let data: LevelData
    private let world = SKNode(), lens = SKCameraNode(), hud = SKNode()
    private var player: SKSpriteNode2dBase!
    private var follow: CameraFollowHelper!
    private var enemies: [Enemy] = []
    private var shots: [Shot] = []
    private var clouds: [(SKSpriteNode, CGPoint)] = []
    private var lastTime: TimeInterval?
    private var delta: TimeInterval = 0
    private var elapsed: TimeInterval = 0
    private var fireCooldown: TimeInterval = 0
    private var invulnerable: TimeInterval = 0
    private var health = 100, score = 0, kills = 0
    private var totalTargets: Int { (data.resources.level.obstacles ?? []).filter { $0.isVisible != false && $0.elementName != "island" }.count }
    private var ended = false
    private var heading = CGFloat.zero
    private var stick = CGPoint.zero
    private var keys: Set<UIKeyboardHIDUsage> = []
    private var steeringTouch: ObjectIdentifier?
    private var firingTouches: Set<ObjectIdentifier> = []
    private var autoFire = true
    private let joystick = SKShapeNode(circleOfRadius: 58)
    private let knob = SKShapeNode(circleOfRadius: 25)
    private let fireButton = SKShapeNode(circleOfRadius: 45)
    private let autoButton = SKShapeNode(rectOf: CGSize(width: 94, height: 28), cornerRadius: 9)
    private let restartButton = SKShapeNode(rectOf: CGSize(width: 92, height: 32), cornerRadius: 10)
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let hint = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let resultPanel = SKNode()
    private var minimapDot = SKShapeNode(circleOfRadius: 3)
    private let minimap = SKShapeNode(rectOf: CGSize(width: 100, height: 100), cornerRadius: 12)
    #if DEBUG
    private let smokeTest = ProcessInfo.processInfo.arguments.contains("--verify-gameplay")
    #else
    private let smokeTest = false
    #endif
    private var smokeReported = false
    private var smokeSequenceComplete = false
    private var cameraTravelled = CGRect.zero
    private var travelled = CGRect.zero
    private var initialCamera = CGPoint.zero
    private var shotsFired = 0, hits = 0, contacts = 0

    init(data: LevelData) throws {
        self.data = data
        super.init(size: data.sceneSize)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .aspectFit
        backgroundColor = UIColor(red: 0.015, green: 0.56, blue: 0.65, alpha: 1)
        physicsWorld.gravity = .zero
        addChild(world); addChild(lens); camera = lens
        lens.addChild(hud); hud.zPosition = 1000
        // Scroller2d API: weak adapter avoids the SDK's retained delegates owning the scene.
        let hooks = Hooks(self); customDelegate = hooks; contactDelegate = hooks
        makeHUD()
        try rebuild()
    }
    required init?(coder: NSCoder) { fatalError("Use init(data:)") }

    private func rebuild() throws {
        releaseControls(); world.removeAllChildren(); enemies.removeAll(); shots.removeAll(); clouds.removeAll()
        resultPanel.removeFromParent(); resultPanel.removeAllChildren()
        health = 100; score = 0; kills = 0; ended = false; heading = 0
        elapsed = 0; fireCooldown = 0; invulnerable = 0; lastTime = nil
        autoFire = true; shotsFired = 0; hits = 0; contacts = 0; travelled = .zero; cameraTravelled = .zero; smokeReported = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        let ocean = renderer.image { context in
            let colors = [UIColor(red: 0.01, green: 0.48, blue: 0.59, alpha: 1).cgColor,
                          UIColor(red: 0.01, green: 0.68, blue: 0.73, alpha: 1).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0,1]) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 64, y: 64), options: [])
            }
        }
        let water = SKSpriteNode(texture: SKTexture(image: ocean), size: data.worldBounds.size)
        water.position = CGPoint(x: data.worldBounds.midX, y: data.worldBounds.midY)
        water.zPosition = -10; world.addChild(water)
        // Deterministic ocean details make motion and direction readable.
        for row in -10...10 {
            for col in -10...10 {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: -15, y: 0)); path.addQuadCurve(to: CGPoint(x: 15, y: 0), control: CGPoint(x: 0, y: 5))
                let ripple = SKShapeNode(path: path)
                ripple.strokeColor = UIColor(white: 1, alpha: 0.12); ripple.lineWidth = 2
                ripple.position = CGPoint(x: col * 155 + (row % 2) * 55, y: row * 155)
                world.addChild(ripple)
            }
        }
        // Use SDK catalog merging and object creation without horizontal-only assembly.
        for (index, entry) in (data.resources.level.obstacles ?? []).enumerated() {
            let model = try data.resources.obstacle(for: entry)
            let node = CreateObstacleHelper(ld: model, node: world, scene: self)
            node.isUserInteractionEnabled = false
            world.addChild(node)
            if entry.elementName == "island" { continue }
            let ship = entry.elementName == "ship"
            if !ship {
                node.color = UIColor(red: 0.85, green: 0.20, blue: 0.17, alpha: 1)
                node.colorBlendFactor = 0.65
                addPropeller(to: node)
            }
            node.zRotation = CGFloat(index) * 1.7
            body(node, radius: ship ? 36 : 27, category: Mask.enemy,
                 contacts: Mask.friendlyShot | Mask.player)
            enemies.append(Enemy(node, ship: ship, delay: 0.7 + Double(index % 4) * 0.4))
        }
        guard let entry = data.resources.level.characters?.first(where: { $0.isVisible != false }) else {
            throw NSError(domain: "Skypirates", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing pilot character placement"])
        }
        let pilot = try data.resources.character(for: entry)
        let start = pilot.devices?.deviceValue(key: .position) as? CGPoint ?? .zero
        let pilotSize = pilot.devices?.deviceValue(key: .size) as? CGSize ?? CGSize(width: 124, height: 124)
        player = SKSpriteNode2dBase(texture: try data.texture(pilot.image ?? "hero_plane"), name: entry.name, position: start,
            size: pilotSize, anchorPoint: CGPoint(x: 0.5,y: 0.5), zPosition: entry.zPosition, gameScene: self)
        player.isUserInteractionEnabled = false
        body(player, radius: 27, category: Mask.player, contacts: Mask.enemy | Mask.enemyShot)
        world.addChild(player); addPropeller(to: player)
        let cloudTexture = try data.texture("cloud")
        for i in 0..<18 {
            let node = SKSpriteNode(texture: cloudTexture, size: CGSize(width: 280 + (i % 3)*50, height: 180))
            let base = CGPoint(x: CGFloat((i * 677) % 3400) - 1700, y: CGFloat((i * 953) % 3400) - 1700)
            node.position = base; node.alpha = 0.55; node.zPosition = 160
            world.addChild(node); clouds.append((node, base))
        }
        // Scroller2d API: both axes, smooth follow, dynamic heading-based look-ahead.
        follow = CameraFollowHelper(camera: lens, target: player, viewportSize: size, bounds: data.worldBounds)
        follow.followsHorizontal = true; follow.followsVertical = true; follow.smoothing = 7
        lens.position = .zero; initialCamera = lens.position
        hint.text = "STEER ANY DIRECTION  ·  AUTO FIRE ON"
        refreshHUD()
        NSLog("SKYPIRATES_READY enemies=%d follow=both", enemies.count)
    }

    private func addPropeller(to plane: SKSpriteNode) {
        let shadow = SKSpriteNode(texture: plane.texture, size: plane.size)
        shadow.color = .black; shadow.colorBlendFactor = 1; shadow.alpha = 0.18
        shadow.position = CGPoint(x: 12, y: -15); shadow.zPosition = -1
        plane.addChild(shadow)
        let prop = SKSpriteNode(texture: data.propellerFrames()[0], size: CGSize(width: 52, height: 12))
        prop.position = CGPoint(x: 0, y: plane.size.height * 0.38); prop.zPosition = 2
        // Scroller2d API: reusable frame playback instead of custom animation timing.
        prop.run(.manualAnimate(frames: data.propellerFrames(), skScene: self, frameRange: nil,
                               idlePerFrameWait: 0.025, frequency: .foreverAutomatically))
        plane.addChild(prop)
    }
    private func body(_ node: SKNode, radius: CGFloat, category: UInt32, contacts: UInt32) {
        let physics = SKPhysicsBody(circleOfRadius: radius)
        physics.affectedByGravity = false; physics.allowsRotation = false; physics.linearDamping = 0
        physics.categoryBitMask = category; physics.contactTestBitMask = contacts; physics.collisionBitMask = 0
        node.physicsBody = physics
    }
    private func direction(_ angle: CGFloat) -> CGPoint { CGPoint(x: -sin(angle), y: cos(angle)) }
    private func angle(to point: CGPoint) -> CGFloat { atan2(-point.x, point.y) }
    private func turn(_ current: CGFloat, toward target: CGFloat, rate: CGFloat) -> CGFloat {
        let difference = atan2(sin(target-current), cos(target-current))
        return current + min(rate, max(-rate, difference))
    }
    private func input() -> CGPoint {
        var value = stick
        if keys.contains(.keyboardA) || keys.contains(.keyboardLeftArrow) { value.x -= 1 }
        if keys.contains(.keyboardD) || keys.contains(.keyboardRightArrow) { value.x += 1 }
        if keys.contains(.keyboardW) || keys.contains(.keyboardUpArrow) { value.y += 1 }
        if keys.contains(.keyboardS) || keys.contains(.keyboardDownArrow) { value.y -= 1 }
        if smokeTest {
            switch Int(elapsed / 2.5) % 4 {
            case 0: value = CGPoint(x: 0, y: 1)
            case 1: value = CGPoint(x: 1, y: 0)
            case 2: value = CGPoint(x: 0, y: -1)
            default: value = CGPoint(x: -1, y: 0)
            }
        }
        return value
    }
    private func step(_ time: TimeInterval) {
        guard let lastTime else { self.lastTime = time; return }
        delta = min(1.0/20, max(0, time-lastTime)); self.lastTime = time
        guard !ended else { return }
        elapsed += delta; fireCooldown -= delta; invulnerable -= delta
        let desired = input()
        if hypot(desired.x, desired.y) > 0.16 {
            heading = turn(heading, toward: angle(to: desired), rate: CGFloat(delta)*4.2)
        }
        let forward = direction(heading)
        player.zRotation = heading
        player.position.x += forward.x * 195 * delta
        player.position.y += forward.y * 195 * delta
        let bounds = data.worldBounds.insetBy(dx: 75, dy: 75)
        player.position.x = min(bounds.maxX, max(bounds.minX, player.position.x))
        player.position.y = min(bounds.maxY, max(bounds.minY, player.position.y))
        if (autoFire || !firingTouches.isEmpty || keys.contains(.keyboardSpacebar)), fireCooldown <= 0 {
            fireCooldown = 0.17
            fire(from: player, hostile: false)
        }
        for enemy in enemies where enemy.node.parent != nil {
            let offset = CGPoint(x: player.position.x-enemy.node.position.x, y: player.position.y-enemy.node.position.y)
            let distance = hypot(offset.x, offset.y)
            if !enemy.ship {
                let destination = distance < 950 ? angle(to: offset) : enemy.node.zRotation + 0.25
                enemy.node.zRotation = turn(enemy.node.zRotation, toward: destination, rate: CGFloat(delta)*1.1)
                let flight = direction(enemy.node.zRotation)
                enemy.node.position.x += flight.x * 95 * delta
                enemy.node.position.y += flight.y * 95 * delta
                if abs(enemy.node.position.x) > 1500 || abs(enemy.node.position.y) > 1500 {
                    enemy.node.zRotation = angle(to: CGPoint(x: -enemy.node.position.x, y: -enemy.node.position.y))
                }
            }
            enemy.cooldown -= delta
            if enemy.cooldown <= 0 && distance < 650 {
                enemy.cooldown = enemy.ship ? 2.5 : 1.8
                fire(from: enemy.node, hostile: true, aim: offset)
            }
        }
        for i in shots.indices { shots[i].age += delta }
        shots.removeAll { shot in
            if shot.age > 2.6 || shot.node.parent == nil { shot.node.removeFromParent(); return true }
            return false
        }
        refreshHUD()
        if smokeTest { verifyGameplay() }
    }
    private func finishFrame() {
        guard player != nil, follow != nil else { return }
        let forward = direction(heading)
        follow.lookAhead = CGVector(dx: forward.x*70, dy: forward.y*70)
        follow.viewportSize = size
        follow.update(deltaTime: delta)
        cameraTravelled = cameraTravelled.union(CGRect(x: lens.position.x, y: lens.position.y, width: 1, height: 1))
        // Nearer cloud layer moves 18% faster across the view than the ocean below.
        for (cloud, base) in clouds {
            let speed = data.resources.level.background?.backgrounds?.first?.speed ?? 0.18
            cloud.position = CGPoint(x: base.x-lens.position.x*speed, y: base.y-lens.position.y*speed)
        }
        minimapDot.position = CGPoint(x: player.position.x/data.worldBounds.width*90,
                                     y: player.position.y/data.worldBounds.height*90)
    }
    private func fire(from node: SKSpriteNode, hostile: Bool, aim: CGPoint? = nil) {
        let rotation = aim.map(angle(to:)) ?? node.zRotation
        let forward = direction(rotation)
        for side in (hostile ? [CGFloat(0)] : [-CGFloat(17), CGFloat(17)]) {
            let bullet = SKSpriteNode(color: .clear, size: CGSize(width: hostile ? 7 : 5, height: 16))
            let glow = SKShapeNode(ellipseOf: bullet.size)
            glow.fillColor = hostile ? .systemOrange : .systemYellow
            glow.strokeColor = hostile ? .systemOrange : .white
            glow.lineWidth = 0.8; glow.glowWidth = 1.5
            bullet.addChild(glow)
            bullet.zRotation = rotation; bullet.zPosition = 110
            bullet.position = CGPoint(x: node.position.x + forward.x*50 + cos(rotation)*side,
                                      y: node.position.y + forward.y*50 + sin(rotation)*side)
            body(bullet, radius: 6, category: hostile ? Mask.enemyShot : Mask.friendlyShot,
                 contacts: hostile ? Mask.player : Mask.enemy)
            bullet.physicsBody?.usesPreciseCollisionDetection = true
            bullet.physicsBody?.velocity = CGVector(dx: forward.x * (hostile ? 270 : 650), dy: forward.y * (hostile ? 270 : 650))
            world.addChild(bullet); shots.append(Shot(node: bullet))
            if !hostile { shotsFired += 1 }
        }
    }
    private func contact(_ contact: SKPhysicsContact) {
        let a = contact.bodyA, b = contact.bodyB
        let mask = a.categoryBitMask | b.categoryBitMask
        if mask == Mask.friendlyShot | Mask.enemy {
            let shot = a.categoryBitMask == Mask.friendlyShot ? a.node : b.node
            let target = a.categoryBitMask == Mask.enemy ? a.node : b.node
            guard let shot, shot.parent != nil, let target, target.parent != nil,
                  let enemy = enemies.first(where: { $0.node === target }) else { return }
            shot.removeFromParent(); enemy.health -= 1; hits += 1
            if enemy.health <= 0 {
                explosion(at: target.position); target.removeFromParent()
                enemies.removeAll { $0 === enemy }; kills += 1; score += enemy.ship ? 250 : 100
                if enemies.isEmpty { finish(won: true) }
            }
        } else if mask == Mask.player | Mask.enemyShot || mask == Mask.player | Mask.enemy {
            let other = a.categoryBitMask == Mask.player ? b.node : a.node
            guard other?.parent != nil else { return }
            if mask == Mask.player | Mask.enemyShot { other?.removeFromParent() }
            guard invulnerable <= 0 else { return }
            contacts += 1; health = max(0, health-20); invulnerable = 1.2
            // Scroller2d API: shared feedback action for damage.
            player.run(.blink(times: 3, duration: 0.8), withKey: "damage")
            if health == 0 { explosion(at: player.position); finish(won: false) }
        }
    }
    private func explosion(at position: CGPoint) {
        for i in 0..<10 {
            let spark = SKShapeNode(circleOfRadius: CGFloat(7+i%4))
            spark.fillColor = i%2 == 0 ? .systemYellow : .systemOrange; spark.strokeColor = .clear
            spark.position = position; spark.zPosition = 180; world.addChild(spark)
            let theta = CGFloat(i) * .pi * 2 / 10
            spark.run(.sequence([.group([.moveBy(x: cos(theta)*65, y: sin(theta)*65, duration: 0.4),
                                         .fadeOut(withDuration: 0.4), .scale(to: 0.15, duration: 0.4)]), .removeFromParent()]))
        }
    }
    private func finish(won: Bool) {
        guard !ended else { return }; ended = true
        refreshHUD()
        releaseControls(); shots.forEach { $0.node.removeFromParent() }; shots.removeAll()
        let panel = SKShapeNode(rectOf: CGSize(width: 390, height: 180), cornerRadius: 24)
        panel.fillColor = UIColor(red: 0.025, green: 0.16, blue: 0.22, alpha: 0.96)
        panel.strokeColor = UIColor.white.withAlphaComponent(0.5)
        resultPanel.addChild(panel)
        let title = label(won ? "SKIES SECURED" : "AIRCRAFT LOST", size: 27)
        title.position.y = 38; resultPanel.addChild(title)
        let summary = label("Score \(score)  ·  Targets \(kills)/\(totalTargets)", size: 18)
        resultPanel.addChild(summary)
        let replay = label("TAP TO FLY AGAIN", size: 18); replay.position.y = -48
        resultPanel.addChild(replay); hud.addChild(resultPanel)
    }
    private func label(_ text: String, size: CGFloat) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: "AvenirNext-Heavy"); node.text = text
        node.fontSize = size; node.fontColor = .white; node.verticalAlignmentMode = .center
        return node
    }
    private func makeHUD() {
        for (position, width) in [(CGPoint(x: -size.width/2+150, y: size.height/2-47), CGFloat(270)),
                                  (CGPoint(x: size.width/2-113, y: size.height/2-37), CGFloat(190))] {
            let panel = SKShapeNode(rectOf: CGSize(width: width, height: 66), cornerRadius: 14)
            panel.fillColor = UIColor(red: 0.025, green: 0.20, blue: 0.27, alpha: 0.72)
            panel.strokeColor = UIColor.white.withAlphaComponent(0.25); panel.zPosition = -1
            panel.position = position; hud.addChild(panel)
        }
        titleLabel.text = "SKYPIRATES"; titleLabel.fontSize = 25
        titleLabel.horizontalAlignmentMode = .left; titleLabel.position = CGPoint(x: -size.width/2+30, y: size.height/2-44)
        hud.addChild(titleLabel)
        statusLabel.fontSize = 15; statusLabel.horizontalAlignmentMode = .left
        statusLabel.position = CGPoint(x: -size.width/2+30, y: size.height/2-69); hud.addChild(statusLabel)
        scoreLabel.fontSize = 21; scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.position = CGPoint(x: size.width/2-30, y: size.height/2-42); hud.addChild(scoreLabel)
        hint.fontSize = 13; hint.position.y = -size.height/2+30; hud.addChild(hint)
        joystick.position = CGPoint(x: -size.width/2+96, y: -size.height/2+90)
        joystick.fillColor = UIColor(red: 0.03, green: 0.22, blue: 0.30, alpha: 0.5)
        joystick.strokeColor = UIColor.white.withAlphaComponent(0.5); joystick.lineWidth = 3
        knob.fillColor = UIColor.white.withAlphaComponent(0.65); knob.strokeColor = .clear
        joystick.addChild(knob); hud.addChild(joystick)
        fireButton.position = CGPoint(x: size.width/2-86, y: -size.height/2+84)
        fireButton.fillColor = .systemRed; fireButton.strokeColor = UIColor.white.withAlphaComponent(0.7)
        fireButton.lineWidth = 3; fireButton.addChild(label("FIRE", size: 20)); hud.addChild(fireButton)
        autoButton.position = CGPoint(x: size.width/2-86, y: -size.height/2+150)
        autoButton.fillColor = UIColor.black.withAlphaComponent(0.3); autoButton.strokeColor = .clear
        autoButton.addChild(label("AUTO ON", size: 12)); hud.addChild(autoButton)
        restartButton.position = CGPoint(x: size.width/2-76, y: size.height/2-75)
        restartButton.fillColor = UIColor.black.withAlphaComponent(0.25); restartButton.strokeColor = .clear
        restartButton.addChild(label("RESTART", size: 12)); hud.addChild(restartButton)
        minimap.position = CGPoint(x: size.width/2-84, y: 25)
        minimap.fillColor = UIColor.black.withAlphaComponent(0.22); minimap.strokeColor = UIColor.white.withAlphaComponent(0.3)
        minimapDot.fillColor = .systemYellow; minimapDot.strokeColor = .clear
        minimap.addChild(minimapDot); hud.addChild(minimap)
    }
    private func refreshHUD() {
        statusLabel.text = "HULL \(health)%   ·   TARGETS \(kills)/\(totalTargets)"
        (autoButton.children.first as? SKLabelNode)?.text = autoFire ? "AUTO ON" : "AUTO OFF"
        scoreLabel.text = String(format: "Score %04d", score)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: hud)
            if ended || restartButton.frame.contains(point) { restart(); return }
            if autoButton.frame.contains(point) { toggleAutoFire(); continue }
            if hypot(point.x-fireButton.position.x, point.y-fireButton.position.y) < 58 {
                firingTouches.insert(ObjectIdentifier(touch)); continue
            }
            if steeringTouch == nil && point.x < 0 {
                steeringTouch = ObjectIdentifier(touch); steer(touch)
            }
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where ObjectIdentifier(touch) == steeringTouch { steer(touch) }
    }
    private func steer(_ touch: UITouch) {
        let point = touch.location(in: joystick)
        let distance = max(1, hypot(point.x, point.y)), reach = min(42, distance)
        knob.position = CGPoint(x: point.x/distance*reach, y: point.y/distance*reach)
        stick = CGPoint(x: knob.position.x/42, y: knob.position.y/42)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch); firingTouches.remove(id)
            if id == steeringTouch { steeringTouch = nil; stick = .zero; knob.position = .zero }
        }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchesEnded(touches, with: event) }
    func key(_ usage: UIKeyboardHIDUsage, pressed: Bool) -> Bool {
        let supported: Set<UIKeyboardHIDUsage> = [.keyboardA,.keyboardD,.keyboardW,.keyboardS,.keyboardLeftArrow,
            .keyboardRightArrow,.keyboardUpArrow,.keyboardDownArrow,.keyboardSpacebar,.keyboardR,.keyboardF]
        guard supported.contains(usage) else { return false }
        if pressed {
            guard keys.insert(usage).inserted else { return true }
            if usage == .keyboardR { restart() }
            if usage == .keyboardF { toggleAutoFire() }
        } else { keys.remove(usage) }
        return true
    }
    private func toggleAutoFire() {
        autoFire.toggle()
        hint.text = autoFire ? "AUTO FIRE ON" : "HOLD FIRE OR SPACE TO SHOOT"
        refreshHUD()
    }
    func releaseControls() { keys.removeAll(); stick = .zero; knob.position = .zero; steeringTouch = nil; firingTouches.removeAll() }
    func setActive(_ active: Bool) { releaseControls(); lastTime = nil; isPaused = !active }
    func stopDemo() { setActive(false) }
    private func restart() {
        do { try rebuild() } catch { hint.text = error.localizedDescription; NSLog("SKYPIRATES_RESTART_FAILED %@", error.localizedDescription) }
    }
    private func verifyGameplay() {
        travelled = travelled.union(CGRect(x: player.position.x, y: player.position.y, width: 1, height: 1))
        guard elapsed > 10, !smokeReported, !smokeSequenceComplete else { return }
        smokeReported = true
        let passed = travelled.width > 200 && travelled.height > 200 && shotsFired > 20 && hits > 0
            && contacts > 0 && cameraTravelled.width > 200 && cameraTravelled.height > 200
            && lens.position.x.isFinite && lens.position.y.isFinite
        NSLog("SKYPIRATES_SMOKE_%@ xRange=%.0f yRange=%.0f shots=%d hits=%d contacts=%d cameraX=%.0f cameraY=%.0f",
              passed ? "PASSED" : "FAILED", travelled.width, travelled.height, shotsFired, hits, contacts, lens.position.x, lens.position.y)
        guard passed else { return }
        smokeSequenceComplete = true
        // Explicitly exercise result presentation and the same restart path used by touch/R.
        finish(won: true)
        let showedResults = ended && resultPanel.parent === hud
        restart()
        let replayed = showedResults && !ended && health == 100 && score == 0 && kills == 0
            && enemies.count == totalTargets && shots.isEmpty && resultPanel.parent == nil
        setActive(false)
        let paused = isPaused && steeringTouch == nil && firingTouches.isEmpty
        setActive(true)
        let resumed = !isPaused && lastTime == nil
        NSLog("SKYPIRATES_REPLAY_%@ pauseResume=%@ targets=%d", replayed ? "PASSED" : "FAILED",
              paused && resumed ? "passed" : "failed", enemies.count)
    }
}
