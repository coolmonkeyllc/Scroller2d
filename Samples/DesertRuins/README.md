# Desert Ruins SpriteKit sample

Run a complete iPhone or iPad game, edit its level in Scroller2d LevelEditor, and see the change in SpriteKit.

[Watch the demonstration](https://scroller2d.com/videos/Scroller2D%20Editor%20to%20Game.mp4) · [Step-by-step tutorial](https://scroller2d.com/Articles/desert-ruins-quickstart) · [Get LevelEditor](https://scroller2d.com/Download)

## Included files

```text
DesertRuins/
  Desert Ruins iOS Demo/       Xcode project, Swift source, asset catalog, and sync scripts
  Desert Ruins Workspace/     Editable level, shared object catalogs, source artwork, and audio
  Scroller2d Api/             Matching Scroller2d.xcframework
```

Keep these three folders together. The Xcode project references
`../Scroller2d Api/Scroller2d.xcframework`; no machine-specific framework path is needed.
The included API contains the level assembly, ground construction, and camera-follow helpers.

## Requirements

- A Mac running an OS supported by Xcode 27.2 or later.
- Xcode 27.2 or later, with a simulator runtime compatible with the project's iOS 26.6 deployment target.
- Scroller2d LevelEditor for editing the workspace. It is not required to run the bundled game.
- Python 3 for the artwork-copy script when syncing editor changes.

## Run the game

1. Clone this repository or download and extract its ZIP.
2. Open [DesertRuins.xcodeproj](Desert%20Ruins%20iOS%20Demo/DesertRuins.xcodeproj).
3. Select the **DesertRuins** scheme and an iPhone or iPad simulator, then choose **Product → Run**.
4. For a physical device, select your own development team and a suitable bundle identifier under **Signing & Capabilities**.

If you replace an older API binary, choose **Product → Clean Build Folder** before rebuilding.
The simulator requires no personal signing team. The included XCFramework supports iOS devices,
iOS simulators, and macOS; the demo app itself targets iOS.

## Play

| Action | Touch controls | Keyboard |
| --- | --- | --- |
| Move | Hold an arrow | Left/right arrows or A/D |
| Jump | JUMP | Space |
| Slash | SLASH | J |
| Restart | RESET or Play Again | R |
| Toggle audio | SOUND | M |

Jump the crate, activate the checkpoint beacon, and cross the first gap. Miss a jump to
try respawning. Continue past the saw, slash the guardian, and recover the relic to
show the Level End results and replay button.

## Edit a coin and run again

1. Open the **Desert Ruins Workspace** folder in LevelEditor using **File → Open Workspace…**.
2. Open `Levels/DesertRuins.plist`, move a coin above the gap, and save.
3. In Terminal, change into `Desert Ruins iOS Demo` and run:

   ```sh
   ./sync-level.sh "../Desert Ruins Workspace"
   ```

4. Build and run the Xcode project again. The coin uses its new position.

The script copies the level, catalogs, and sound files, and regenerates
`DesertRuins/LevelArt.xcassets` from the workspace images. Commit your editor artwork
changes in the workspace before regenerating; direct edits to the generated catalog
can be overwritten. For a placement-only change, you can instead copy
`Levels/DesertRuins.plist` from the workspace into the demo's `DesertRuins/Levels` folder.

LevelEditor also supports using artwork in place from an Xcode asset catalog or SpriteKit
atlas. See the [demo README](Desert%20Ruins%20iOS%20Demo/README.md#share-artwork-between-leveleditor-and-xcode)
for that workflow and the sample's category-prefixed asset names.

## Follow the implementation

- **LevelData.swift** loads the level and catalogs using `LevelAssemblyHelper.Resources` and maps asset names.
- **GameScene.swift** uses `LevelAssemblyHelper` to resolve defaults and create configured nodes, with `GroundConstructionHelper` constructing terrain and collision surfaces.
- **CameraFollowHelper** follows the player with look-ahead and bounds. This sample follows horizontally; the helper also supports vertical-only and combined-axis following.
- Existing Scroller2d obstacle, character, animation, scene-lifecycle, and contact helpers supply reusable runtime behavior.
- The game supplies controls, player state selection, parallax wrapping, pickups, combat, checkpoint state, and Level End UI.

Ground construction and assembly currently support flat horizontal terrain and gaps.
Sloped, stacked, and hazard ground types require a custom ground builder.

For an automated gameplay check, add `--verify-gameplay` to the scheme's Debug launch
arguments. The console reports `DESERTRUINS_SMOKE_PASSED` or `DESERTRUINS_SMOKE_FAILED`.
Remove the argument for normal play.

## Licensing

The sample can run with a missing-license notice. Scroller2d's data models are free to
use; scene classes and runtime helpers require an API license. To clear the notice,
generate your own `api_license.plist` in a licensed copy of LevelEditor, then add it to
the demo target's **Copy Bundle Resources** phase so it is copied to the app bundle root.
Personal license files are excluded from this repository.

The free editor has per-category save limits; saving edits to the complete Desert Ruins
level requires a paid license. See [downloads and licensing](https://scroller2d.com/Download#licensing)
for the current terms. There is no per-game-install fee or separate maintenance fee.

The supplied artwork and audio may be reused without attribution, as described in the
[workspace README](Desert%20Ruins%20Workspace/README.md#reuse). Scroller2d software and API
license terms are separate; including the framework does not grant an API license.
