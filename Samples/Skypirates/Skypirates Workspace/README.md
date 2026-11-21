# Skypirates workspace

Open this folder in Scroller2d LevelEditor, then open `Levels/Skypirates.plist`.
The level uses a 960 × 540 design scene with `scrollOrientation` set to `both`.
Positions extend across a larger playable map; pan the canvas to inspect them.

- **Characters:** the pilot's start, image, and size.
- **Obstacles:** islands, six raiders, and three patrol boats.
- **Background:** the cloud layer image and its parallax factor.

The iOS demo reads the existing Scroller2d model and catalog formats. Raider artwork
is tinted red by game code; its editor preview uses the shared green airplane image.
The cloud distribution and world boundaries are set in the demo's Swift code.

After editing and saving, run `./sync-level.sh "../Skypirates Workspace"` from the
sibling Skypirates iOS Demo folder, then build and run the app again. The script's
canonical hero artwork source is `Assets/Images/Characters/hero_plane.png`; the copy
under Obstacles is supplied for editor preview.

The artwork is AI-generated; provenance and software licensing are documented in the
sibling demo's README and ARTWORK.md. No personal API license is included.
