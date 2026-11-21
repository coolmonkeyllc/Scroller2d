// Copyright (c) 2026 Cool Monkey LLC
// SPDX-License-Identifier: MIT
// Demo Swift source only; see ../LICENSE.

import SpriteKit
import UIKit
import Scroller2d

@MainActor
final class LevelData {
    let resources: LevelAssemblyHelper.Resources
    let worldBounds = CGRect(x: -1600, y: -1600, width: 3200, height: 3200)
    var sceneSize: CGSize { resources.level.settings.size?.toCGSize() ?? CGSize(width: 960, height: 540) }

    init() throws {
        guard let root = Bundle.main.resourceURL else { throw CocoaError(.fileNoSuchFile) }
        // Scroller2d API: existing level and catalog formats also describe a free-roaming level.
        resources = try LevelAssemblyHelper.Resources(
            levelURL: root.appendingPathComponent("Levels/Skypirates.plist"),
            obstacleURL: root.appendingPathComponent("Assets/ObstacleList.plist"),
            characterURL: root.appendingPathComponent("Assets/CharacterList.plist"),
            objectURL: root.appendingPathComponent("Assets/ObjectList.plist"))
    }

    func texture(_ name: String) throws -> SKTexture {
        guard let image = UIImage(named: name) else {
            throw NSError(domain: "Skypirates", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Missing image set: \(name)"])
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    /// Small original blade frames; Scroller2d handles the repeated playback action.
    func propellerFrames() -> [SKTexture] {
        (0..<6).map { index in
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 12))
            let image = renderer.image { context in
                let width = max(4, abs(cos(CGFloat(index) * .pi / 6)) * 60)
                UIColor(white: 0.95, alpha: 0.65).setFill()
                UIBezierPath(roundedRect: CGRect(x: 32-width/2, y: 3, width: width, height: 6), cornerRadius: 3).fill()
            }
            return SKTexture(image: image)
        }
    }
}
