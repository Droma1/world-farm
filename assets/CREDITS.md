# Asset Credits

All third-party assets are **CC0 1.0 (public domain)** unless otherwise noted —
no attribution required, but credited here as good practice.

## Texturas PBR realistas — `assets/textures/pbr/`

Source: **Poly Haven** (CC0 1.0)
URL: <https://polyhaven.com/textures>

| Archivo | Asset slug | Uso |
|---------|------------|-----|
| `floor_diff.jpg` + `floor_nor.jpg` | `rough_concrete` | Suelo del mapa |
| `wall_diff.jpg` + `wall_nor.jpg` | `concrete_wall_007` | Muros y pilares |
| `wood_diff.jpg` + `wood_nor.jpg` | `wood_planks` | Cajas de cobertura, laberinto |
| `metal_diff.jpg` + `metal_nor.jpg` | `metal_plate` | Plataformas, cajones cargo |

Resolución 1K (1024×1024). Cada textura tiene su **normal map** (`_nor_gl`) para
PBR real (relieves visibles según iluminación). Aplicadas con triplanar mapping
en `StandardMaterial3D`.

## Texturas prototype — `assets/textures/proto/`

Source: **Kenney — Prototype Textures** (CC0 1.0)
URL: <https://kenney.nl/assets/prototype-textures>

| Archivo | Original |
|---------|----------|
| `floor.png` | Light/texture_01 |
| `wall.png` | Dark/texture_06 |
| `crate.png` | Orange/texture_01 |
| `platform.png` | Green/texture_05 |

Usadas en armas (rifle), cuerpos de Player y Enemy, y cualquier prop pequeño
donde texturas PBR de 1K serían exageradas.

## Audio — `assets/audio/sfx/`

Todo Kenney, CC0 1.0.

### `weapon/`
- Source: **Kenney — Sci-Fi Sounds** (`laserLarge_*`) y **Kenney — UI Audio** (`switch1`)
- URLs: <https://kenney.nl/assets/sci-fi-sounds>, <https://kenney.nl/assets/ui-audio>
- Files: `shoot_01..03.ogg`, `reload_click.ogg`

### `impact/`
- Source: **Kenney — Sci-Fi Sounds** (`impactMetal_*`, `slime_*`)
- URL: <https://kenney.nl/assets/sci-fi-sounds>
- Files: `wall_01..03.ogg`, `flesh_01..02.ogg`

### `footstep/`
- Source: **Kenney — Impact Sounds** (`footstep_wood_*`)
- URL: <https://kenney.nl/assets/impact-sounds>
- Files: `step_01..05.ogg` — paso de bota sobre madera (más natural que el concrete usado antes).

---

## Cómo añadir más assets

1. Mantener licencia compatible (idealmente CC0 o CC-BY).
2. Añadir entrada a esta tabla con fuente + URL + licencia.
3. Si la licencia exige attribution (CC-BY), incluir el nombre del autor.
4. Para binarios grandes (>1 MB), considerar Git LFS.
