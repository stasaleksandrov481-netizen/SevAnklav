# Новые растровые материалы — 30.10.2026

Созданы встроенным ImageGen и подключены к настоящим 3D-материалам проекта. Это текстуры, а не подмена игровых кадров. Кадры обзора сняты отдельно в Godot 4.7. Оригинальные ответы генератора сохранены без перерисовки; для игровых материалов включены mipmaps. Прозрачность лица сохраняется и используется при проекции на объёмную голову.

## Материалы ящиков

Файл: `iso/maps/level2/textures/storage_surfaces.png`.

```text
Use case: stylized-concept. Asset type: a single production diffuse material texture atlas for existing industrial storage crates in the dark Soviet underground bunker game Severny Anklav. Create a square image split precisely into a 2 by 2 grid of equal square material swatches, touching edge to edge without gutters or borders. Top left: weathered olive painted plywood with subtle horizontal wood grain and scuffs, no framing. Top right: desaturated dark blue gray painted steel with fine scratches, chipped paint and subtle oxidation, no framing. Bottom left: faded beige canvas fabric, tightly woven with mild dirt and folds but flat overall. Bottom right: dull raw galvanized steel with fine wear. These are flat closeup surface materials, not objects: orthographic straight-on scans, evenly lit diffuse/albedo only, no baked directional lighting, no perspective, no cast shadows, no text, no logos, no bolts, no handles, no outside environment. Realistic restrained material detail, clearly distinct readable surfaces for small mobile game objects, avoid excessive rust and high contrast dirt. Exactly four equal quadrants aligned to center, 1024 by 1024 preferred.
```

## Материалы одежды

Файл: `assets/characters/volkov_surfaces.png`.

```text
Use case: stylized-concept. Asset type: a production diffuse/albedo texture material atlas for a realistic adult male survivor character in the existing underground bunker game Severny Anklav. One square image, precisely 2 by 2 equal square material swatches without borders or gaps. Top left: subdued slate blue gray woven field-jacket twill, fine fabric weave, soft irregular creases and restrained worn seams, no garment outline. Top right: dark olive drab uniform trouser fabric with mild dust and fine weave. Bottom left: natural light warm Caucasian human skin surface with subtle pores and variation, no facial features, no eyes, no face, no strong blemishes. Bottom right: worn dark charcoal boot leather with subtle creases, no shoe outline, no metal. These are flat macro surface scans, not four objects. Even neutral diffuse light, no directional shadows or baked highlights, no writing, no logos, no interface. Materials must read clearly at small mobile-game scale; realistic restrained texture and no excessively gritty noise. Exact equal quadrants aligned to image center.
```

## Текстура лица

Файл: `assets/characters/volkov_face.png`.

```text
Use case: stylized-concept. Asset type: frontal face diffuse texture for the curved head of a realistic adult male game character, fictional survivor Alexey Volkov, age 34. Single head only on truly transparent background, no torso, no neck, no shoulders. Front orthographic view looking straight forward, neutral relaxed expression, mouth closed, natural human proportions. Closely cropped dark brown hair, light muted Caucasian skin, subtle short stubble, slight under-eye fatigue, gray brown eyes. Natural photorealistic game-asset skin detail with diffuse flat even illumination from all directions, no dramatic light, no cast shadow, no gloss, no backdrop, no makeup, no scars. The head must fill almost all the square canvas from chin at bottom to hair at top, centered, symmetrical front orientation, ears at the sides, no angle or perspective. It will be projected as a diffuse texture onto existing 3D head geometry; prioritize natural features and evenly lit texture, avoid cartoon, stylized blocky anatomy, toy appearance, enlarged eyes, open mouth, labels or watermark.
```
