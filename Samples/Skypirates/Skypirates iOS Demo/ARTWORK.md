# Skypirates artwork provenance

The concept and four sprite images were generated for this demo with OpenAI's
built-in image-generation tool. The concept was used as the style reference for
the individual sprites. No external asset pack or artist reference was supplied.
The sprites have transparent backgrounds and are stored in `Skypirates/LevelArt.xcassets`.
The matching source images are in the sibling Skypirates Workspace folder.

The artwork is AI-generated. It should not be described as hand-drawn, guaranteed
unique, or guaranteed copyright-free. The demo code's MIT license does not relicense
OpenAI services or override applicable terms for generated output.

## Prompt set

All sprites used this common direction: one isolated production game sprite on a
truly transparent background; the Skypirates concept is a style reference only;
straight overhead orthographic view; rounded chunky forms, bold dark navy outlines,
clean silhouettes, restrained internal detail, two-tone cel shading; whole object
visible with transparent margin; no text, logos, watermark, or game-screen layout.

### Concept — Artwork/skypirates-concept.png

A polished landscape screenshot-style concept for Skypirates, a free-roaming iOS
SpriteKit game. Straight overhead orthographic view of a WWII-inspired propeller
fighter dogfight over a turquoise ocean archipelago. An olive-green hero with cream
wing stripes, yellow nose, blue canopy, and visible spinning propeller points
upper-right, firing twin yellow streams at red enemy aircraft. A small patrol boat,
sandy islands with rounded green trees and rocks, and white foreground clouds give
separate depth layers. Simple rounded cartoon game art, dark outlines, limited
internal detail, two-tone shading, no real military insignia. Modest navy HUD with
SKYPIRATES, hull percentage, score, virtual joystick, and FIRE button. No device frame.

### hero_plane

The olive-green hero propeller fighter from the concept, viewed straight down,
nose exactly up and wings horizontal. Rounded chunky forms, navy outlines, cream
wing stripes, warm yellow nose, blue canopy, symmetrical aircraft. Omit the spinning
propeller so the game can animate it separately. No bullets, trails, ground,
external shadows, text, logos, or insignia. Centered, roughly 85% canvas occupancy.

### patrol_ship

One small rounded cartoon patrol boat viewed straight down, bow exactly up. Muted
red hull with navy outline, cream deck, small grey cabin, and visible round gun
turret. No wake, water, external shadow, or background. All parts visible and centered.

### island

One small tropical island terrain sprite, straight down. Irregular sandy coastline,
three rounded green trees, a few smooth grey rocks, grassy center. Broad flat colors,
two-tone shading, restrained detail, dark outlines on trees. Entire coastline visible.
No water, aircraft, sky, words, or external background.

### cloud

One fluffy white cloud viewed from above, rounded lobes and simple pale blue shadow
shapes. Soft pale outline, no dark outline. Airy silhouette, centered and fully
visible. No sky, ocean, text, or other objects.

## Runtime artwork

Ocean gradient and wave lines, propeller frames, projectile glows, explosion sparks,
shadows, and controls are drawn by the demo in SpriteKit/UIKit. Raiders reuse the
hero texture with a red runtime tint. `SKAction.manualAnimate` from Scroller2d plays
the generated blade frames. No music or audio files are included.
