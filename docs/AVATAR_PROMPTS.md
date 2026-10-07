# Create your own companion

Use a photograph you have permission to use. These prompts work as a starting specification for image-generation tools; no particular provider is required. Your photo is processed by the external tool you select, not by DeskBuddy.

## 1. Idle character → idle.png

Attach your photo and copy:

```text
Create one beautiful, friendly, full-body 3D cartoon/chibi desktop mascot based on the person in my attached photo. Use only the person; remove the complete original background. Preserve recognizable face shape, skin tone, hairstyle, facial hair if present, and clothing style. Use a larger expressive head, compact body, soft rounded clay-like rendering, warm natural shading and a gentle smile. Standing comfortably, slight three-quarter turn, hands relaxed. Complete any cropped legs with simple matching trousers and shoes. Keep the entire person visible from hair to shoes with modest padding. Actual transparent RGBA background, no scene, floor, shadows, text, logos, watermark, frame or additional characters. This must read clearly as a small desktop emoji. Export as transparent PNG.
```

## 2. Animation sheet → animation-sheet.png

Attach the generated idle character as the reference and copy:

```text
Create ONE animation sprite sheet using the supplied character as the exact identity, outfit and 3D cartoon style reference. EXACTLY eight full-body poses in a strict four-column by two-row grid of equally sized cells. Use a landscape canvas, preferably 1536×1024 pixels; dimensions must be divisible by four horizontally and two vertically. Same character scale, camera, head size and foot baseline across all cells. At least 10% transparent padding in every cell; no overlap or clipping. Row 1 left to right: four right-facing walk-cycle poses, alternating feet and arms, with two passing stances. Row 2 left to right: lifting a light-blue water glass toward mouth; sipping with glass tilted at lips; smiling thumbs-up; playful friendly shrug with palms up. Preserve the exact same face, hair, skin tone and outfit in all eight poses. Real transparent RGBA background throughout, including cell corners. No grid lines, labels, text, ground, shadows, backdrop, extra characters or props except the water glass in the two drinking poses. Export one transparent PNG.
```

## Validate before import

- A checkerboard painted into the image is not transparency. Inspect the alpha channel in your image tool.
- Confirm all eight poses, equal cells and complete feet/head. The app checks file validity and dimensions, not pose semantics.
- Save exactly `idle.png` and `animation-sheet.png` in one folder, each below 20 MB.
- Import through Settings; do not alter the signed app bundle.
- To reduce jitter, regenerate a sheet with identical character scale and baseline. More than eight poses are not supported by the current loader.
