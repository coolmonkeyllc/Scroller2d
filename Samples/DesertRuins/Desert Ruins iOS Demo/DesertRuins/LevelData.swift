import AVFoundation
import Scroller2d
import SpriteKit
import UIKit

enum LevelError: LocalizedError {
    case missing(String)
    case invalid(String)

    /// Converts resource and Scroller2d decoding failures into user-facing messages.
    var errorDescription: String? {
        switch self {
        case .missing(let name): "Missing resource: \(name)"
        case .invalid(let name): "Invalid Scroller2D data: \(name)"
        }
    }
}

/// Loads editor exports into Scroller2d model objects and resolves their runtime assets.
///
/// Scroller2d API usage in this type is called out with `Scroller2d API:` comments.
@MainActor
final class LevelData {
    // Scroller2d public models decoded from the LevelEditor property lists.
    let resources: LevelAssemblyHelper.Resources
    let level: Level
    let obstacles: [Obstacle]
    let characters: [Character]
    let objects: [GenericObject]
    let sceneSize: CGSize
    private let assets: URL
    private let audio = GameAudio()
    var muted = false {
        didSet {
            let muted = muted
            Task { await audio.setMuted(muted) }
        }
    }

    /// Loads the level and catalogs, using Scroller2d's config loader for its native data formats.
    init() throws {
        guard let root = Bundle.main.resourceURL else { throw LevelError.missing("App resources") }
        assets = root.appendingPathComponent("Assets", isDirectory: true)
        let levelURL = root.appendingPathComponent("Levels/DesertRuins.plist")
        // Scroller2d API: load the level and its catalogs through one throwing API.
        resources = try LevelAssemblyHelper.Resources(
            levelURL: levelURL,
            obstacleURL: assets.appendingPathComponent("ObstacleList.plist"),
            characterURL: assets.appendingPathComponent("CharacterList.plist"),
            objectURL: assets.appendingPathComponent("ObjectList.plist")
        )
        level = resources.level
        guard let sceneSize = level.settings.size?.toCGSize(),
              sceneSize.width > 0, sceneSize.height > 0,
              level.settings.scrollOrientation == "horizontal" else {
            throw LevelError.invalid(levelURL.lastPathComponent)
        }
        self.sceneSize = sceneSize
        obstacles = resources.obstacles
        characters = resources.characters
        objects = resources.objects
    }

    /// Builds the asset-catalog name used by exported level elements.
    func catalogName(_ name: String, in category: String) -> String {
        "\(category)_\(name)"
    }
    
    /// Uses Scroller2d's scene texture cache to retrieve every frame in an exported animation atlas.
    func animation(_ name: String, in category: String, scene: AppSharedSceneBase) throws -> [SKTexture] {
        let asset = catalogName(name, in: category)
        guard !SKTextureAtlas(named: asset).textureNames.isEmpty else {
            throw LevelError.missing("Sprite atlas \(asset)")
        }
        // Scroller2d API: `AppSharedSceneBase` owns the reusable texture-atlas cache.
        let frames: [SKTexture] = scene.retrieveTexture(atlasName: asset)
        frames.forEach { $0.filteringMode = .nearest }
        return frames
    }

    /// Creates a nearest-filtered SpriteKit node for a static exported image asset.
    func sprite(_ name: String, in category: String, size: CGSize,
                at position: CGPoint, z: CGFloat) throws -> SKSpriteNode {
        let texture = try texture(name, in: category)
        let sprite = SKSpriteNode(texture: texture, size: size)
        sprite.position = position
        sprite.zPosition = z
        return sprite
    }

    /// Maps an editor image name to the bundled image set used by the terrain helper.
    func texture(_ name: String, in category: String) throws -> SKTexture {
        let asset = catalogName(name, in: category)
        guard let image = UIImage(named: asset) else { throw LevelError.missing("Image set \(asset)") }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }

    /// Resolves a Scroller2d `GameSound` model to its bundled audio file and starts playback.
    func play(_ sound: GameSound?, looping: Bool = false) {
        guard let sound else { return }
        let file = assets.appendingPathComponent("Sounds/\(sound.filename)")
            .appendingPathExtension(sound.soundExtension)
        let volume = Float(sound.volume ?? 0.5)
        Task { await audio.play(file, volume: volume, looping: looping) }
    }

    /// Stops all audio when the running demo is torn down.
    func stopAudio() {
        Task { await audio.stop() }
    }
}

private actor GameAudio {
    private var effects: [AVAudioPlayer] = []
    private var music: AVAudioPlayer?
    private var muted = false
    private var stopped = false
    private lazy var audioReady = Task.detached(priority: .userInitiated) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient)
            if #available(iOS 27.0, *) {
                return try await session.activate(options: [])
            }
            try session.setActive(true)
            return true
        } catch {
            NSLog("DesertRuins audio session: %@", error.localizedDescription)
            return false
        }
    }

    /// Applies mute state, stopping effects and pausing or resuming background music.
    func setMuted(_ muted: Bool) {
        self.muted = muted
        if muted {
            music?.pause()
            effects.forEach { $0.stop() }
            effects.removeAll()
        } else {
            music?.play()
        }
    }

    /// Stops and releases every active music and sound-effect player.
    func stop() {
        stopped = true
        music?.stop()
        music = nil
        effects.forEach { $0.stop() }
        effects.removeAll()
    }

    /// Waits for the audio session, then plays a one-shot effect or replaces looping music.
    func play(_ file: URL, volume: Float, looping: Bool) async {
        guard await audioReady.value, !stopped, looping || !muted else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: file)
            player.volume = volume
            if looping {
                music?.stop()
                music = player
                player.numberOfLoops = -1
            } else {
                effects.removeAll { !$0.isPlaying }
                effects.append(player)
            }
            if !muted { player.play() }
        } catch {
            NSLog("DesertRuins audio: %@", error.localizedDescription)
        }
    }
}

@MainActor
/// Reads a point field from Scroller2d's device-specific property array.
func point(_ devices: [DeviceProperties]?, _ key: fieldList = .position) -> CGPoint {
    devices?.deviceValue(key: key) as? CGPoint ?? .zero
}

@MainActor
/// Reads a Scroller2d device size, using `fallback` when its dimensions are unusable.
func dimensions(_ devices: [DeviceProperties]?, fallback: CGSize = .zero) -> CGSize {
    // Scroller2d API: select the value matching the current device from exported properties.
    let result = devices?.deviceValue(key: .size) as? CGSize ?? .zero
    return result.width > 0 && result.height > 0 ? result : fallback
}
