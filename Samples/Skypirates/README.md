# Skypirates

A top-down iPhone/iPad game demonstrating Scroller2d camera following in all 2D
directions, with propeller aircraft, enemy raiders, patrol boats, islands, and clouds.

![Actual Skypirates gameplay](Skypirates%20iOS%20Demo/Artwork/skypirates-gameplay.png)

## Run

1. Open [Skypirates.xcodeproj](Skypirates%20iOS%20Demo/Skypirates.xcodeproj) in Xcode 27.2 or later.
2. Choose the **Skypirates** scheme and an iPhone or iPad simulator, then Run.
3. Steer with the left joystick or WASD/arrows. Automatic firing starts enabled;
   tap AUTO to toggle it, hold FIRE/Space for manual shots, and use RESTART/R to replay.

The project uses the matching API already included under
`Samples/DesertRuins/Scroller2d Api` through a relative path. Keep the sample folders
together when cloning or downloading the repository. No extra API copy is needed.

## Explore

- [Full setup, controls, API integration, and verification](Skypirates%20iOS%20Demo/README.md)
- [Editable LevelEditor workspace](Skypirates%20Workspace/README.md)
- [Artwork provenance and prompts](Skypirates%20iOS%20Demo/ARTWORK.md)
- [Approved visual concept](Skypirates%20iOS%20Demo/Artwork/skypirates-concept.png)
- [Demo Swift MIT license](Skypirates%20iOS%20Demo/LICENSE)

The API's data models, catalog resolver, object creation, scene/contact delegates,
animation helpers, and both-axis camera follower are used directly. Flight and combat
rules remain game code. The API's horizontal terrain builders are not used here.

A runtime API license is separate from the MIT-licensed sample Swift code. The app
can run with a missing-license notice; use your own generated API license to clear it.
The artwork is AI-generated and is separate from the demo code's MIT license.
