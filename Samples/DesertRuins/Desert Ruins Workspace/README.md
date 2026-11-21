# Desert Ruins

Desert Ruins is a horizontal 874 × 402 landscape sample for Scroller2d LevelEditor. The explorer starts beside a flowering cactus, passes a supply crate and checkpoint beacon, jumps a 120-point gap along a coin trail, and reaches a saw, guardian, spikes, and a relic gate.

## Open the level

1. In LevelEditor, choose **File → Open Workspace…** and select the **Desert Ruins Workspace** folder.
2. Choose **File → Open Level…** and open **Levels/DesertRuins.plist**.
3. Pan right with the canvas navigation controls to see the saw, guardian, and relic gate.

Keep the workspace folder together when moving or sharing it. Its file layout follows the editor's bundled Sample Workspace.

## Assets

- **Assets/Images/Backgrounds** contains an opaque sky and three transparent ridge layers with separate scroll speeds.
- **Assets/Images/Ground** contains repeating sandstone, left and right edge tiles, and the transparent gap tile.
- **Assets/Images/Obstacles** contains a cactus, crate, spikes, gate, and the eight-frame `watch_saw` sequence.
- **Assets/Images/Checkpoints** contains the three-frame checkpoint beacon. The checkpoint sits 49 scene points before the first gap.
- **Assets/Images/Coins** and **Artifacts** contain the Sundrop coin and Sun Relic.
- **Assets/Images/Characters** contains four sequences each for `dune_explorer` and `ruin_guardian`. All character frames use a 128 × 96 transparent canvas. Frame filenames start at `_00` and are in playback order.
- **Assets/Sounds** contains the 20-second `desertruins_theme.wav` loop, `blade_slash.wav`, `stone_hit.wav`, and `checkpoint_chime.wav`. The theme is referenced by the level background and the effects by the relevant object properties.

| Character sequence suffix | Frames | Suggested timing |
|---|---:|---|
| `Idle` | 6 | 0.17 s per frame, loop |
| `Running` | 8 | 0.08 s per frame, loop |
| `Jumping` | 6 | 0.09 s per frame, once |
| `Slash` | 6 | 0.07 s per frame, once |

The editor canvas displays the placed assets. The sibling iOS sample provides player input, switches character states (including Jumping), plays sounds in response to game events, and demonstrates collision and scrolling behavior. For the checkpoint demo, activate the beacon, miss the jump, and respawn at the beacon.

## Level End

The Level End section defines the results panel shown after the player takes the Sun Relic in the iOS demo. It includes a title, description, coin and relic totals, elapsed time, a replay item, and the synthesized `level_complete.wav` sound in `Assets/Sounds`.

## Reuse

The sample began with procedural artwork and synthesized audio. Its visuals were later refined with AI assistance toward rounded, outlined cartoon sprites. See [ARTWORK.md](../Desert%20Ruins%20iOS%20Demo/ARTWORK.md) for the current inventory, provenance notes, and asset workflow. The explorer is an original adventure character.

The art and audio in this workspace may be copied, edited, used commercially, and redistributed without attribution. To the extent any rights in those assets are held by the creator of this package, they are waived to the extent permitted by law. This applies to the supplied art and audio. Scroller2d software and API license terms are separate.
