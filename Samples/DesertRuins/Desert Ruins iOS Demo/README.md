# Desert Ruins for iOS

Run the Scroller2D LevelEditor sample as a landscape SpriteKit game on iPhone or iPad. The demo bundles the same level plist and artwork used by the editor.

## Build and run

1. Keep this demo beside the supplied `Scroller2d Api` folder. The project references `../Scroller2d Api/Scroller2d.xcframework` using a relative path. Use the updated binary containing the three level helpers. If replacing an older API in an existing checkout, choose **Product → Clean Build Folder** before rebuilding.
2. Open `DesertRuins.xcodeproj` in Xcode 27.2 or later. Select the **DesertRuins** scheme and an iPhone or iPad simulator, then Run. The target’s deployment setting is iOS 26.6.
3. For hardware, select your development team under **Signing & Capabilities**, then choose your device. Use a unique bundle identifier if needed for signing.

This repository includes the demo source, artwork, audio, and matching Scroller2d XCFramework in the sibling `Scroller2d Api` folder. The framework includes iOS device, iOS simulator, and macOS slices. This sample uses the SDK’s data models, scene class, and node helpers.

## API license

The demo Swift source is [MIT licensed](LICENSE) and may be reused commercially
with the required notices. The API, LevelEditor, and assets have separate terms;
see [component licensing](../LICENSING.md).

The sample can run with a missing-license notice. To clear the notice, generate your own
`api_license.plist` using **Generate api key** in a licensed copy of LevelEditor. Add it to
the demo target's **Copy Bundle Resources** phase so it is copied to the app bundle root.
Do not commit your license file; the repository ignores it. The API's data models are
free to use; its scene classes and runtime helpers require an API license.
See [downloads and licensing](https://scroller2d.com/Download#licensing).

## Play

| Action | Touch | Hardware keyboard or Simulator |
|---|---|---|
| Move | Hold either arrow | Left/right arrows or A/D |
| Jump | Tap **JUMP** while moving | Space |
| Slash | Tap **SLASH** | J |
| Reset the run | **RESET** | R |
| Toggle audio | **SOUND** | M |

Jump the crate and run past the beacon. Its teal flag and **BEACON LIT** indicator show that it saved your position. Walk into the gap to demonstrate respawning, then hold right and jump near the lip to clear it. Jump the saw, slash the guardian from a short distance, jump the spikes, and touch the relic to open the Level End results. **Play Again** or **R** restores coins, the beacon, and enemies for another take.

## Where Scroller2D is used

- `LevelData.swift` loads the level and all three catalogs with `LevelAssemblyHelper.Resources`. The helper exposes the existing SDK models and throws decoding errors. Catalog defaults and non-nil placement overrides merge recursively, with device records matched by exact `deviceName`.
- `GameScene` subclasses `AppSharedSceneBase`. Its lifecycle and contact delegates drive the demo. The scene’s ground-height helper seats the beacon and finds the respawn height. The scene also caches the animated textures.
- `CreateObstacleHelper` places the obstacles, creates their physics bodies, and animates the saw. `CreateCharacterHelper` builds the guardian as an `SKSpriteNodeEnemy2dBase`, and the SDK’s enemy update handles its idle animation and facing. The player uses `SKSpriteNode2dBase` with the SDK’s rectangle physics helper and `SKAction.manualAnimate` for its poses.
- `LevelAssemblyHelper.build` constructs a detached level root with ground, obstacles, and the configured guardian factory. The demo maps catalog image names in `configureObstacle`, supplies its physics masks, and keeps a two-point ground collision inset. `assembly.install` attaches the root, applies scene settings, and commits the ground lookup and end point. The demo explicitly selects `aspectFit` afterward for its complete touch HUD.
- `GroundConstructionHelper` creates repeated ground tiles, gaps, and merged static collision surfaces. The demo uses the returned surfaces for grounded checks. Flat horizontal terrain is supported; slopes, stacked sections, and hazard ground types need a custom builder.
- `CameraFollowHelper` follows the player after physics with a 90-point look-ahead and level limits. Zero smoothing preserves the original camera response; the API also supports smoothing and vertical following. Refresh the visible world viewport size after resizing or camera zoom.
- The demo supplies input, the controllable player, pickups, parallax wrapping, combat rules, checkpoint state, and the Level End UI. The API supplies assembly, catalog merging, ground construction, and camera-follow behavior.

## Level End

Open the level’s **Level End** properties in LevelEditor to edit the results title, description, item positions, and finish sound. The app uses the level’s `levelEnd.windowItems` to lay out the panel and fills in the actual coin total, elapsed time, and relic count at completion. The relic is the finish trigger for this sample. The in-game Replay item starts a fresh run.

## Share artwork between LevelEditor and Xcode

### Copy assets with the sample script

From the demo directory, run `./sync-level.sh "/path/to/Desert Ruins Workspace"`, then build and run again. The script copies the saved level, object lists, and WAV files into the iOS project. It uses Python 3 to copy the source PNGs into a regenerated `DesertRuins/LevelArt.xcassets`. Standalone PNGs become image sets, and folders of numbered frames become SpriteKit atlases. For a quick editor-to-game test, move a coin in LevelEditor, save, and run the script to see the new position in the app.

### Use existing Xcode artwork in place

In LevelEditor, choose **File → Manage Image Sources… → Add Folder** and select the artwork folder inside your Xcode project. You can link a regular image folder, a source `.xcassets` catalog or one of its subfolders, or a SpriteKit `.atlas` or `.spriteatlas` folder. The editor reads the project artwork from that location, so a separate copy of those images in the workspace is optional.

Use **Available for** to assign each source to the relevant editor category, such as Characters or Backgrounds. Under **Atlas interpretation**, choose **Animation** to expose an atlas as one animation or **Individual Images** to expose its members. **Automatic** recognizes a continuous sequence named after its atlas, such as `dune_explorer_Idle_00`, `dune_explorer_Idle_01`, and so on in `dune_explorer_Idle.spriteatlas`. Click **Refresh** after changing the files.

Match the names saved in the level to the names your game resolves at runtime. This demo’s generated catalog uses category-prefixed names such as `Characters_dune_explorer_Idle`, while its existing level refers to `dune_explorer_Idle`. When adopting the in-place workflow for this demo, keep that mapping in mind and manage the linked catalog directly. The sync script rebuilds `LevelArt.xcassets` from the workspace images, so use it only when you want to regenerate that catalog.

For an automated simulator check, pass `--verify-gameplay` as a Debug launch argument. The app drives the controls and writes a `DESERTRUINS_SMOKE_PASSED` or `DESERTRUINS_SMOKE_FAILED` line to the console. Remove the argument to play or record manually.

The original sample art and audio may be reused without attribution. Scroller2D’s software and API license terms are separate.

For asset provenance, source dimensions, reconstructed design briefs, and the audio
inventory, see [ARTWORK.md](ARTWORK.md).
