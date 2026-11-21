# Desert Ruins licensing

This sample contains components with separate license terms. The demo's MIT
license applies to its Swift source code only.

## Demo Swift code — MIT

The `*.swift` files in `Desert Ruins iOS Demo` and its subdirectories are licensed
under the [MIT License](Desert%20Ruins%20iOS%20Demo/LICENSE).
You may copy, modify, redistribute, and use this code commercially, subject to
retaining the copyright and permission notices required by that license.

This permission covers the demo's integration and gameplay code. It does not
relicense Scroller2d itself or grant permission to use its licensed runtime
features without an API license.

## Artwork and audio

The supplied sample artwork and audio, including copies in the demo's asset
catalog and sound folders, may be reused under the separate permissions in the
[workspace README](Desert%20Ruins%20Workspace/README.md#reuse). Those permissions
allow copying, editing, commercial use, and redistribution without attribution.
The demo Swift code's MIT notice requirement does not change those asset permissions.

## Scroller2d API and LevelEditor

The `Scroller2d Api/Scroller2d.xcframework` binary and Scroller2d LevelEditor
are excluded from the demo's MIT license. Their own software and API license
terms apply. The same exclusion applies to any API implementation supplied
separately; calling the API from MIT-licensed demo code does not relicense it.

Scroller2d's data models are free to use. Its scene classes and runtime helpers
require an API license generated through a licensed copy of LevelEditor.
The sample can run with a missing-license notice; use your own `api_license.plist`
to clear it. Personal license files must not be committed to this repository.

The free editor has per-category save limits. Saving edits to the full Desert
Ruins level requires a paid license. There is no per-game-install fee or separate
maintenance fee. See [downloads and licensing](https://scroller2d.com/Download#licensing)
for the product's licensing information.

## Other files

This document does not grant an MIT license to the repository as a whole.
The demo's scripts, project configuration, level data, catalogs, and other files
are not covered by the Swift-source-only MIT grant unless separately stated.
