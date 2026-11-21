# Desert Ruins artwork and audio

This document describes the assets used by the Desert Ruins iOS demo, their design
direction, and the workflow that imports them into SpriteKit.

## Provenance

The sample began with procedurally created artwork and synthesized music and sound
effects, as described in its original workspace documentation. The visual assets
were subsequently refined with AI assistance toward a rounded, polished cartoon
style with less internal detail. The design process included a user-supplied
cartoon clothing image as a style reference; that reference image is not bundled
as a game asset.

The exact generation/edit prompts, model versions, and intermediate images from
those earlier iterations are not archived with this sample. The briefs below are
reconstructed design guidance, not a verbatim generation record. The current art
should not be described as entirely hand-drawn or entirely procedural, and AI
assistance does not establish guaranteed uniqueness or copyright clearance.

The audio is documented as synthesized from scratch. Its original synthesis
scripts are not included in this sample, so `sync-level.sh` copies the supplied
WAV files rather than recreating them.

## Visual direction

A friendly desert adventure with an original explorer character, a ruin guardian,
flowering cactuses, sandstone platforms, collectible coins, and a relic gate.

- Rounded silhouettes with bold dark outlines.
- Restrained internal detail and broad, readable color areas.
- Simple highlights and shadows instead of fine surface texture.
- Warm sandstone and sunset colors, with teal checkpoint accents.
- Exaggerated character poses that read at the game's small display sizes.
- Consistent sprite dimensions and transparent padding across animation frames.

The explorer is a generic adventure character. The sample is named Desert Ruins;
internal identifiers such as `dune_explorer`, `sundrop_coin`, and `sun_relic` are
asset names, not references to a licensed entertainment property.

## Source artwork inventory

Source PNGs live in the sibling workspace's `Assets/Images` directory. Dimensions
below are the PNG canvas sizes in pixels, not necessarily the configured scene sizes.

| Category | Files or sequences | Canvas size | Frames |
| --- | --- | --- | --- |
| Backgrounds | `sky`, `far_ridges`, `mesa_ridges`, `cactus_ridges` | 874 × 402 | One PNG per layer |
| Characters | `dune_explorer_Idle`, `ruin_guardian_Idle` | 128 × 96 | 6 each |
| Characters | `dune_explorer_Running`, `ruin_guardian_Running` | 128 × 96 | 8 each |
| Characters | `dune_explorer_Jumping`, `ruin_guardian_Jumping` | 128 × 96 | 6 each |
| Characters | `dune_explorer_Slash`, `ruin_guardian_Slash` | 128 × 96 | 6 each |
| Checkpoints | `desertruins_beacon` | 60 × 88 | 3 |
| Coins | `sundrop_coin` | 32 × 32 | 1 |
| Artifacts | `sun_relic` | 50 × 56 | 1 |
| Ground | `sandstone`, `sandstone_left`, `sandstone_right` | 96 × 56 | One PNG each |
| Ground | `transparent_ground` | 120 × 56 | 1 |
| Obstacles | `bloom_cactus` | 68 × 106 | 1 |
| Obstacles | `trail_crate` | 64 × 64 | 1 |
| Obstacles | `iron_spikes` | 96 × 48 | 1 |
| Obstacles | `relic_gate` | 184 × 156 | 1 |
| Obstacles | `watch_saw` | 80 × 80 | 8 |

Animation frame filenames are numbered from `_00` and are loaded in sorted order.
The transparent ground image represents a gap; do not fill it with visible artwork.

## Reconstructed asset briefs

These describe how to maintain or extend the existing style. They are not the
original prompts and do not guarantee matching animation poses automatically.

### Shared sprite brief

Create a rounded, polished 2D cartoon game asset with a bold dark outline, clear
silhouette, broad color areas, minimal internal detail, and simple two-tone shading.
Keep the existing canvas size, orientation, transparent padding, and scene alignment.
Do not include labels, watermarks, or a baked-in background on a transparent sprite.

### Explorer and guardian

An original desert adventurer with a broad-brimmed hat and readable adventuring
outfit, and a distinct ruin guardian. Produce idle, running, jumping, and slashing
poses with exaggerated movement. Keep each character's proportions, costume,
lighting, and foot/body alignment consistent across its 128 × 96 frames.

### Backgrounds

A sunset desert sky and separate distant ridges, mesas, and cactus silhouettes.
Use broad shapes and restrained detail so gameplay objects remain readable. Retain
874 × 402 canvases, the sky's opaque coverage, and transparency on overlay layers.
Check the joins when the game repeats background tiles for parallax.

### Terrain and obstacles

Rounded sandstone platform tiles and matching left/right caps. A flowering cactus,
wooden supply crate, iron spikes, and a ruin gate use the same outline and shading
language. Keep terrain seams aligned. Preserve the eight-frame saw sequence and its
80 × 80 canvas so the animation remains centered.

### Collectibles and checkpoint

A warm gold coin, a distinctive sun relic, and a teal checkpoint beacon. Favor clear
silhouettes and readable highlights at their existing sizes. Keep the three beacon
frames aligned so activation changes the state without moving the sprite.

## Audio inventory

WAV files are stored under `Assets/Sounds` in both the workspace and bundled demo.
Durations are rounded from the supplied files.

| File | Purpose | Duration |
| --- | --- | --- |
| `desertruins_theme.wav` | Looping background music | 20.00 s |
| `blade_slash.wav` | Player attack | 0.27 s |
| `stone_hit.wav` | Impact feedback | 0.18 s |
| `checkpoint_chime.wav` | Checkpoint activation | 0.46 s |
| `level_complete.wav` | Level End feedback | 0.95 s |

Playback volume, looping, and event selection are controlled by the level/catalog
sound properties and the demo's audio code. This document does not claim that
reconstructed visual briefs can regenerate these audio files.

## Asset-catalog import

From the Desert Ruins iOS Demo folder, run:

```sh
./sync-level.sh "../Desert Ruins Workspace"
```

The script copies the level, catalogs, and sound files, then calls `import-art.py`
to regenerate `DesertRuins/LevelArt.xcassets` from the workspace's source images.
Standalone PNGs become image sets. Sequence folders become `.spriteatlas` folders
containing numbered image sets. The importer copies PNGs without resizing them.

Runtime asset names have category prefixes. For example:

- `Ground/sandstone.png` becomes `Ground_sandstone`.
- `Characters/dune_explorer_Idle/` becomes the `Characters_dune_explorer_Idle` atlas.
- `Obstacles/watch_saw/` becomes the `Obstacles_watch_saw` atlas.

`LevelData.catalogName` maps editor names to these runtime names. The scene's
Scroller2d texture cache retrieves animation frames; `manualAnimate` and the
SDK's configured node helpers handle the relevant animation playback.

Prefer editing source PNGs in the workspace. Regenerating the catalog replaces
direct edits made only inside `LevelArt.xcassets`. LevelEditor can also link an
existing Xcode asset catalog or SpriteKit atlas in place; see the demo README's
[artwork workflow](README.md#share-artwork-between-leveleditor-and-xcode).

## Reuse and license scope

The existing [workspace reuse statement](../Desert%20Ruins%20Workspace/README.md#reuse)
permits copying, editing, commercial use, and redistribution of the supplied sample
artwork and audio without attribution, to the extent of rights held by the package's
creator. This document records that existing permission; it does not guarantee
third-party rights clearance or create rights the creator does not hold.

The demo Swift code's MIT notice requirement is separate from those asset
permissions. Scroller2d API binaries and LevelEditor retain their own license terms.
See the demo [README](README.md) for software licensing and setup information.
