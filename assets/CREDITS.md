# Asset Credits

All third-party assets are **CC0 1.0 (public domain)** unless otherwise noted —
no attribution required, but credited here as good practice.

## Modelos 3D generados con IA — `assets/models/`

Generados con **Meshy.ai** a partir de los prompts del documento
`docs/capibara_operator_concept.md` (estilo cartoon estilizado, Halo-inspired).

| Archivo | Tipo | Notas |
|---------|------|-------|
| `models/characters/capibara_player_rigged.glb` | Personaje | **Capibara con esqueleto humanoid (20 bones)**. Activo en `Player.tscn`. Bones: `pelvis, spine_01/02, neck, head, shoulder/upper_arm/forearm/hand_L/R, thigh/shin/foot_L/R, neutral_bone`. Sin animaciones bakeadas — procedural vía `HumanoidAnimator`. |
| `models/characters/puma_rigged.glb` | Enemigo | **Puma con rig humanoid + cola articulada (23 bones)**. Misma estructura que el capibara más `tail_01/02/03`. Animación de cola con whip-style sway (phase offset por segmento). Activo en `Enemy.tscn`. |
| `models/pickups/mecha.glb` | Pickup / power-up | Mecha invocable. Reservado para feature futura: paquete aleatorio que aparece en combate y permite al jugador pilotar el mecha temporalmente. No instanciado todavía. |
| `models/weapons/rifle_halo.glb` | Arma | Rifle de asalto bullpup tipo MA5C-K. Se usa en `scenes/weapons/RifleHalo.tscn`. |
| `models/weapons/knife.glb` | Arma | Cuchillo táctico K-Bayonet. Se usa en `scenes/weapons/Knife.tscn`. |
| `models/props/solar_outpost.glb` | Prop | Casa "Last Solar Outpost" — outpost habitable post-apocalíptico. Instanciada en `TrainingMap.tscn`. |
| `models/props/ruins_wall.glb` | Prop | Muro "Mossy Ruins" — fragmento de muro cubierto de musgo. Reutilizable como cobertura. |

**Licencia Meshy**: free tier permite uso comercial de los assets generados
(verificar términos vigentes en meshy.ai antes de publicar).
**Pistola** (`pistol_halo.glb`): pendiente de generar.

## Texturas PBR realistas — `assets/textures/pbr/`

Source: **Poly Haven** (CC0 1.0)
URL: <https://polyhaven.com/textures>

| Archivo | Asset slug | Uso |
|---------|------------|-----|
| `floor_diff.jpg` + `floor_nor.jpg` | `rough_concrete` | Suelo del mapa |
| `wall_diff.jpg` + `wall_nor.jpg` | `concrete_wall_007` | Muros y pilares |
| `wood_diff.jpg` + `wood_nor.jpg` | `wood_planks` | Cajas de cobertura, laberinto |
| `metal_diff.jpg` + `metal_nor.jpg` | `metal_plate` | Plataformas, cajones cargo |
| `fur_diff.jpg` + `fur_nor.jpg` | `leather_white` | Pelaje del Player capibara (tinteado) |

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

> Para una **lista completa de fuentes recomendadas** (Poly Haven,
> AmbientCG, Kenney, Quaternius, Mixamo, Sonniss, etc.) con notas de uso,
> ver [`docs/ASSET_SOURCES.md`](../docs/ASSET_SOURCES.md).
