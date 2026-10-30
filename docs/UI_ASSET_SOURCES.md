# UI artwork sources

Generated with the built-in image_gen tool for this project, using the user-supplied inventory and menu/HUD/terminal concept images. The source references are `1000024689.png` and `1000024688.png`; these reference images are not included in the repository. All captions, buttons, item amounts, wounds, messages and terminal navigation are rendered by Godot.

The generated originals were copied into the project without pixel edits. AtlasTexture regions select the item sprites. Vector UI icons are native SVG assets. Roboto Condensed is bundled with its SIL Open Font License in `assets/ui/bunker/OFL.txt`.

## assets/ui/bunker/menu_background.png

Prompt:

Edit the supplied game artwork into a production background asset for the main menu of Северный Анклав. Use the winter bunker entrance and cinematic materials of the TOP PANEL of reference image 2 and the same world in image 1. Landscape 16:9, 1536x864. Deliver ONLY CLEAN BACKGROUND ART, not a UI mockup. Remove ALL letters, logos, titles, buttons, interface frames, HUD and overlays. Snowy secret Soviet bunker in a dark pine forest and mountains at night; massive circular blast door and concrete entrance occupying right half, red emergency lamps with wet ground reflections, small watchtower in distance, a tiny helicopter high in the sky. One dark clothed survivor seen from behind in the center foreground, around x=0.52, with head below upper third and boots near bottom; do not place him in the left menu area. Leftmost 32 percent is quiet dark forest/mist and negative space for our REAL interface; keep it dark, no bright details there. Crisp realistic concept art, cold blue-black slate, muted steel, restrained red light, atmospheric cinematic darkness but visible physical details. Preserve the bunker mood and industrial design from the supplied images. No monsters. No UI or text of any kind.

## assets/ui/bunker/items.png

Prompt:

Production game UI asset: one coherent 4 by 4 INVENTORY ICON SPRITE SHEET, 2048x2048 square, transparent background, every tile 512x512, isolated objects centered with generous 70px padding, no grid lines, no labels, no writing, no shadows outside tiles. Match the subdued realistic physical object thumbnails in the provided inventory reference: weathered Soviet bunker survival gear, cold charcoal, faded khaki, restrained blue glass and dark red fabric, natural material texture, clear silhouette, soft studio light. NOT cartoon, not colorful mobile game icons, no UI frames. Each tile contains exactly ONE distinct item, in exact reading order: Row1: blue-tinted clear plastic water bottle; worn olive metal ration tin; rolled white medical bandage; dark red canvas first aid kit with small pale cross. Row2: amber glass medicine vial with dark red label without letters; small cardboard box of pistol ammunition with three brass cartridges; folded dark khaki uniform jacket; red and brass ceramic electrical fuse. Row3: worn metal access card with perforated corner and no writing; steel repair pliers; old black handheld flashlight; Soviet Makarov pistol in side profile. Row4: compact dark AK rifle in side profile; black handled utility knife; single old brass key; sealed small cylindrical laboratory sample canister. All items fit entirely inside their own cells. Exactly 16 objects arranged in four evenly spaced rows and four evenly spaced columns. This is an asset sprite sheet for implementation, NOT a UI screenshot.

Only the 13 existing item types are mapped. Unused atlas cells add no game items.

## assets/ui/bunker/terminal_bezel.png

Prompt:

Create ONE production game UI asset, a photorealistic industrial terminal BEZEL FRAME overlay matching the monitor surround in the BOTTOM RIGHT of the supplied reference. Landscape 16:9 1536x864. Orthographic straight frontal view, no perspective angle. Only the rectangular physical monitor surround is present: worn blackened bronze steel, scratched dark brown painted metal, small exposed screws and recessed fasteners at corners and on sides, subtle grime, a thin inner desaturated teal rubber lip, chunky softly rounded outer corners. Frame fills the canvas almost edge to edge. All four rails about 50 pixels thick with an INNER OPENING as large as possible. The entire central opening must be genuinely transparent alpha, absolutely empty, so our real interactive text and controls render there. Outside the rounded frame also transparent. No screen image, no black rectangle filling the center, no glass glare over the center, no text, labels, symbols, logos, cables, UI or buttons. Realistic material detail on the frame rails only. It is a reusable empty frame texture, not a screenshot or an illustration of a whole computer.

## assets/ui/bunker/paper.png

Prompt:

One production 2D game UI texture: a single blank sheet of aged paper, straight-on flat scanner view, landscape-ish portrait ratio 5:4 (1000 wide by 800 high). The sheet occupies 96 percent of the canvas, with genuinely transparent alpha outside its outline. Off-white muted warm gray cream, lightly weathered paper fibers, tiny dark flecks, delicate stains near the edges, natural fold creases into thirds with a horizontal center fold. Uneven ragged torn edges, a small torn-away upper right corner, a few small edge nicks. Center is flat, clean and light, very low-contrast, with lots of blank writing space for live readable text in our game. Paper from an abandoned Soviet bunker personnel office, understated believable material. No existing text, handwriting, printing, markings, letters, pictures, stamps, blood, fire damage, clips, shadows on external background, or other objects. Top down orthographic, no perspective distortion, no curl that interferes with the writing area.
