# Fini launcher and assistant assets

Generated with the built-in `image_gen` tool on 2026-11-17, one call per distinct asset. No fallback CLI, credential inspection, paid API runner, bitmap repair, crop, resize, compositing or postprocessing was used. The selected tool PNGs were copied byte-for-byte into this Flutter workspace. Existing `assets/images/fini.png`, old level illustrations and level data were left unchanged.

## Reference

`assets/images/fini.png` was visually inspected, then passed to both calls as the character-identity reference. Fini retains orange fur, cream cheeks/muzzle/ear interiors, brown eyes, coral scarf, green overalls and gold buttons.

## Launcher master

- Workspace path: `assets/branding/fini-launcher-master.png`
- Generated original: `/Users/noname/.codex/generated_images/01a1e818-376e-7a70-9ec1-3a6ed9fa43a5/exec-22532794-3b04-4108-a379-e1c394ddd6ff.png`
- Actual file: PNG, RGB, **1254 × 1254**, fully opaque.
- SHA-256: `a9f36ee4541af0028bcd21dbfe6ff0810254aaf2b6dbfcb064ca2f16d3751c5e`
- Built-in call: `transparent_background: false`; reference path as above.
- Visual inspection: friendly centered Fini head and upper torso, clean square corners, warm mint/cream background, no text/frame/border, eyes and smile clear, clothes consistent with reference. The tool returned 1254 pixels rather than the requested 1024; platform icon generation should consume the actual dimensions.
- Mask note: ears are tall and close to the upper edge. Native icon generation must apply appropriate adaptive foreground padding and inspect circle/squircle masks; this master alone does not prove platform-mask acceptance.

### Exact prompt

```text
Use case: logo-brand
Asset type: production mobile app launcher icon master, one square 1024×1024 full-bleed opaque PNG.
Input image: /Users/noname/Desktop/personal-projects/mobileapp/assets/images/fini.png is a CHARACTER IDENTITY reference, not an edit target. Match this specific friendly Fini fox: vivid warm orange fur, tall fox ears with cream inner fur, broad cream muzzle and cheeks, large kind brown eyes, small dark brown nose, coral-red neck scarf, forest-green overalls with two gold buttons. Keep the recognizable original storybook illustration quality, tactile soft fur and clean expressive shapes.
Primary request: create an exceptionally clear friendly app icon portrait of Fini, facing front with a slight welcoming tilt and a gentle open smile. Head, ears and upper shoulders only, scarf and top of green overalls visible. Head and ears must fit completely within the square, with all essential features inside the central 76 percent; no parts of ears touching edges. The fox should occupy most of the icon and remain recognizable at 48px.
Scene/backdrop: fully opaque very pale warm mint-to-cream background edge to edge, softly lit, with no scene, props or ground. Warm polished children's educational app mood.
Composition/framing: centered balanced bust portrait, large face; silhouette and eye contrast legible at tiny size; consistent natural anatomy. Slight illustrative depth, no heavy cast shadow.
Constraints: actual square image, full bleed square corners. No text, no letters, no logos, no watermark, no frame, no border, no rounded-corner mask, no sticker outline, no white surrounding canvas. Do not include extra animals, hands, objects or decorative confetti. Do not redesign Fini's clothes, colors, face or species.
```

## Assistant wave atlas

- Workspace path: `assets/images/fini-wave-sheet.png`
- Generated original: `/Users/noname/.codex/generated_images/01a1e818-376e-7a70-9ec1-3a6ed9fa43a5/exec-1d8cfa48-0c3e-49aa-887b-eba7cac4f7a8.png`
- Actual file: PNG, RGBA, **1774 × 887**, genuine alpha from 0 to 255.
- SHA-256: `07e007d6c93f3ea0249ed77b175e8d688d82a4050dc1d3abe0d9a8db77dcfff5`
- Built-in call: `transparent_background: true`; reference path as above.
- Atlas geometry: **4 columns × 2 rows**, row-major frames 0–7, equal **443.5 × 443.5 source cells**. Use double precision source rectangles derived from image width/4 and height/2, rather than integer truncation. The tool did not return the requested 2048×1024.
- Alpha inspection: 719,455 pixels have alpha 0; the range is 0–255. At alpha >32 the body bounds within each approximately 443–444px inspection cell have x=13…432 and y=18…411, leaving visible gutters and avoiding material pose overlap. Very faint alpha <8 fringe reaches some cell boundaries; avoid per-frame tight crops.
- Visual inspection: eight distinct waist-up wave drawings, visible paw/forearm articulation, eyelids closing and reopening around frames 2/3/4, modest tail changes. No extra arms or obvious extra digits were observed. Body scale and baseline are sufficiently aligned for a small assistant, with slight 1–2px baseline variation.
- Loop limitation and runtime adaptation: frame 7 is not an exact duplicate of frame 0. Use a ping-pong frame order `0,1,2,3,4,5,6,7,6,5,4,3,2,1` for continuous return movement; do not claim an exact 8→1 cyclic duplicate. Keep a fixed cell-size canvas so pose bounds do not change layout. Runtime crop/animation and reduced-motion behavior require application verification.

### Exact prompt

```text
Use case: illustration-story
Asset type: a production animation SPRITE SHEET with eight actual distinct animation drawings of one recurring character, exactly FOUR COLUMNS by TWO ROWS. Transparent PNG, entire canvas 2048 pixels wide by 1024 pixels high, eight equal SQUARE cells each 512 by 512 pixels. NO grid lines. Genuinely transparent alpha background, no opaque backdrop, no checkerboard drawn into pixels.
Input image: /Users/noname/Desktop/personal-projects/mobileapp/assets/images/fini.png is the CHARACTER IDENTITY reference. Preserve this exact friendly orange fox Fini with cream cheeks and muzzle, brown eyes, dark nose, coral red scarf, green overalls with two gold buttons, storybook soft painted fur. No redesign.
Primary request: build a clean loop of the friendly fox waving hello and briefly blinking. Draw Fini WAIST-UP centered within every square cell with a visible curved cream-tipped tail on the left and waving paw on the right. Same head position, same body position and scale, same torso baseline and camera across ALL cells. Each drawing fits entirely inside its own square with at least 40px of transparent margin on left, right and top; torso ends at y=460 within every cell. NO overlap across cells and no duplicate background.
Animation order, read left to right across top row then bottom row:
Cell 1: neutral welcoming open eyes, right upper arm lifted outward, forearm upright and paw gently tilted outward.
Cell 2: same unchanged torso and head position, waving paw tilted inward by 15 degrees, tail slightly left.
Cell 3: paw tilted inward by 30 degrees, eyelids half-closed in blink, tail slightly further left.
Cell 4: paw returns toward upright, eyes fully closed for blink, tail begins return.
Cell 5: paw upright, eyes half-open reopening, tail centered.
Cell 6: paw tilts outward by 15 degrees, eyes fully open, tail slightly right.
Cell 7: paw tilts outward by 30 degrees, eyes open, tail returns toward center.
Cell 8: same gesture and pose as cell 1 to close the loop exactly, eyes open and smiling.
Use clearly readable but modest HAND/FOREARM wave motion, tail-tip motion and actual eyelid animation; keep the face, torso, clothes and scale locked. The waving paw is a simplified animal paw, THREE rounded fingers and one thumb, consistent in all frames, never extra digits or extra limbs. Other arm stays resting at waist at identical position.
Style: polished warm children's book illustration with cohesive lighting, soft tactile fur, clean silhouette and small-screen clarity. Beautiful friendly Fini expression, consistent anatomy and same likeness in all eight drawings.
Constraints: EXACT uniform 4×2 rectangular layout. No text, letters, frame numbers, captions, grid, lines, labels, arrows, borders, drop shadows or watermark. No ground or colored squares. No additional characters. No combined contact sheet on opaque paper. This must be a truly transparent sprite atlas whose equally sized cells can be cropped directly by a game renderer without edits.
```

## Verification boundary

Generated originals were displayed and inspected and their PNG dimensions, color modes, alpha extrema, per-cell alpha bounds and SHA-256 hashes checked locally. These checks establish the source artifacts and atlas geometry. The generating agent did not run Flutter or native SDK commands; application rendering and launcher installation are separate verification work.

