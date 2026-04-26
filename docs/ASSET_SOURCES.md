# Fuentes de Assets Gratuitos

Guía curada de sitios donde sacar **texturas, audios, modelos 3D y fuentes**
con licencias compatibles para gamedev. Ordenado por categoría con notas
sobre qué tipo de cosas vale la pena buscar en cada uno.

> **Regla general**: prefiere **CC0** (dominio público, sin atribución
> requerida). CC-BY funciona pero obliga a mantener un archivo de créditos
> con autor. Evita CC-BY-SA en proyectos comerciales (te obliga a la misma
> licencia copyleft).

---

## 🎮 Estilo Fortnite / Stylized (low-poly + cel-shaded)

> **La verdad incómoda**: el "look Fortnite" es una **dirección de arte**,
> no un set de texturas descargables. Los assets de Fortnite son
> hand-painted específicamente para sus modelos. Lo que SÍ podemos
> conseguir gratis o barato es **estética similar**: low-poly + colores
> saturados + toon shading + texturas pintadas a mano.

### Synty Studios — POLYGON series (PAID, gold standard)
- **URL**: <https://syntystore.com>
- **Licencia**: comercial, ~$30 USD por pack (el pack único, royalty-free).
- **Por qué importa**: es el estándar de facto de assets "Fortnite-like" en
  el mercado indie. Catálogo enorme: POLYGON Modern, POLYGON City, POLYGON
  Sci-Fi Space, POLYGON Apocalypse, POLYGON Western, etc.
- **Qué incluye por pack**: 100-300 props + 5-30 personajes riggeados +
  texturas atlas + animaciones (idle/walk/run/attack/die/etc).
- **Cuándo invertir**: cuando el juego pase de prototipo a producción real.

### Quaternius — el Synty gratis (FREE, CC0)
- **URL**: <https://quaternius.com>
- **Licencia**: CC0 1.0 — comercial OK, sin atribución.
- **Estilo**: low-poly stylized, similar (no idéntico) a Fortnite. Más
  simple geométricamente, paletas saturadas.
- **Packs imprescindibles**:
  - **Ultimate Stylized Characters** (~30 personajes humanoid riggeados)
  - **Ultimate Animated Animals** (perros, gatos, lobos, **capibara**, etc.
    riggeados con walk/run/idle)
  - **Ultimate Modular Buildings** (kit de edificios stylized)
  - **Ultimate Nature** (árboles, plantas, rocas low-poly)
  - **Ultimate Weapons Pack** (rifles, pistolas, granadas low-poly)
- **Formato**: `.glb` (glTF binary) con texturas atlas embebidas.
- **Workflow Godot**: arrastrar `.glb` al `FileSystem` panel → instanciar
  como nodo. El `AnimationPlayer` interno tiene las animaciones listas.

### Kenney.nl — packs stylized chunky
- **URL**: <https://kenney.nl/assets>
- **Licencia**: CC0
- **Estilo**: chunky low-poly, más "Minecraft con bordes redondeados" que
  Fortnite. Aún así muy útil para prototipos.
- **Packs útiles para Fortnite-vibe**:
  - **Mini Characters Pack** — 20+ chibi humanoides riggeados
  - **City Kit (Suburban)** — props/edificios suburbanos
  - **Castle Kit** — torres y muros stylized
  - **Tower Defense Kit** — torres y enemigos cartoony
  - **Cartoon FX** — explosiones, partículas, hits visuales
- **Formato**: `.glb`, `.fbx`, `.obj`.

### Itch.io stylized search
- **URL**: <https://itch.io/game-assets/free/tag-stylized>
- **Licencia**: variable — filtra explícitamente por CC0/CC-BY.
- **Útil para**: packs temáticos indie (post-apoc, magic, sci-fi) donde
  Quaternius/Kenney no llegan.

### Sketchfab — filter "Stylized" + "Free + downloadable"
- **URL**: <https://sketchfab.com/3d-models/categories/characters-creatures?features=downloadable&price=free>
- **Licencia**: variable. Filtra por CC0 o CC-BY.

### Mixamo — animaciones gratis
- **URL**: <https://www.mixamo.com>
- **Licencia**: free con cuenta Adobe, comercial OK.
- **Por qué importa para Fortnite-style**: tiene 1500+ animaciones de
  mocap profesional (incluyen "shooting", "reload", "victory dance",
  "crouch walk"). Le subes tu mesh humanoid sin riggear, te lo riggea
  automáticamente y le aplicas las animaciones que quieras.
- **Workflow**: subes `.fbx` → Mixamo riggea + animaciones → bajas `.fbx`
  con esqueleto → importas en Godot que detecta el `AnimationPlayer`.

### Cómo replicar el "look Fortnite" SIN bajar nuevos assets

Lo que importa es la dirección de arte — se puede aplicar a primitivos
o a tus propios modelos. Lo que hace que algo "se vea Fortnite":

1. **Toon shading** (cel-shaded). En Godot 4 viene built-in:
   ```
   diffuse_mode = 3   # DIFFUSE_TOON
   specular_mode = 1  # SPECULAR_TOON
   ```
   Aplícalo a `StandardMaterial3D`. La luz queda en pasos discretos en
   vez de gradiente suave → look cartoon.

2. **Colores saturados** — sube los albedo_color hacia el 1.0 en su
   componente dominante. Body color marrón normal `(0.55, 0.36, 0.22)` →
   stylized `(0.85, 0.50, 0.25)`. La saturación es lo que hace "popear".

3. **Normal maps suaves** — `normal_scale` bajo (0.4-0.7 en lugar de 1.0).
   El detalle realista de relieves se ve "demasiado real" para stylized.

4. **Ambient brillante + sombras suaves**:
   ```
   ambient_light_energy = 0.85   # más alto que default 0.4
   ssao_enabled = false          # SSAO oscurece esquinas, anti-stylized
   ```

5. **Geometría low-poly** — pocas caras, bordes visibles. Si pasas de
   primitivos a modelos custom, mantén polycount bajo (1-3k tris por
   personaje, no 50k).

6. **Outline (post-proceso)** — Fortnite no usa outlines marcados, pero
   estilos como Borderlands sí. Para Godot: shader screen-space que
   detecta bordes via depth/normal.

---

## Texturas (PBR y prototype)

### Poly Haven — <https://polyhaven.com/textures>
- **Licencia**: CC0 1.0
- **Calidad**: alta, fotorealista. PBR completo (albedo + normal + roughness + AO + displacement).
- **Resoluciones**: 1K, 2K, 4K, 8K, 16K. Para juegos: 1K-2K es lo recomendable.
- **API directa**: `https://api.polyhaven.com/files/<slug>` devuelve JSON con todas las URLs.
- **CDN directo**: `https://dl.polyhaven.org/file/ph-assets/Textures/<format>/<resolution>/<slug>/<slug>_<map>_<resolution>.<ext>`
- **Búsqueda útil**: concrete, wood, metal, brick, stone, fabric, leather.
- **Limitación**: no tiene fur/animal-skin específico. Usa `leather_white` como base tintable.

### AmbientCG — <https://ambientcg.com>
- **Licencia**: CC0 1.0
- **Catálogo**: gigantesco (~4000 texturas). Más variedad que Poly Haven en categorías nicho.
- **Descarga**: páginas individuales con ZIP completo (1K/2K/4K/8K).
- **Búsqueda útil**: Fabric (telas, fur-like), Ground (suelos naturales), Wood (variantes), Bark (cortezas, sirven como fur orgánico), Tiles, Rock.
- **Pro tip**: para fur de animal, prueba `Fabric046` (felpa), `Bark004` (orgánico irregular).

### Kenney.nl — <https://kenney.nl/assets>
- **Licencia**: CC0 1.0
- **Estilo**: stylized / prototype, no realista. Perfecto para grayboxing.
- **Packs útiles**:
  - `Prototype Textures` — grids de colores para grayboxing rápido (lo que usamos en `assets/textures/proto/`).
  - `Roguelike Tiles` — tile sprites 2D.
  - `Patterns` — texturas geométricas tilebles.

### CGBookcase — <https://cgbookcase.com>
- **Licencia**: CC0
- **Ofrece**: PBR realista (similar a Poly Haven pero con assets que no están allá).
- **Descarga**: ZIP con todos los maps PBR.
- **Útil para**: Variantes que no encuentres en Poly Haven (cuero específico, pieles, ropa).

### Textures.com (antes CGTextures) — <https://www.textures.com>
- **Licencia**: **MIXTA** — gratis con cuenta tiene cap diario de 15 imágenes y restricciones. Lee la EULA antes.
- Útil cuando todo lo demás falla, pero verifica licencia caso por caso.

### Pixabay — <https://pixabay.com>
- **Licencia**: Pixabay License (similar a CC0 — no atribución, comercial OK).
- **Útil para**: fotos referencia que se pueden tilear (skies, terrain backgrounds).
- **Cuidado**: a veces hay assets subidos con licencia ambigua. Verifica.

---

## Audio (SFX y música)

### Kenney.nl Audio — <https://kenney.nl/assets/category:Audio>
- **Licencia**: CC0
- **Packs útiles**:
  - `Sci-Fi Sounds` — laser, impacts, beeps (lo que usamos para shoot/impact).
  - `Impact Sounds` — footsteps por superficie (concrete/wood/grass/snow).
  - `UI Audio` — clicks, switches.
  - `Voiceover Pack` — ~700 frases pre-grabadas en inglés ("ready", "objective complete"...).
  - `Digital Audio` — bleeps electrónicos.

### Freesound — <https://freesound.org>
- **Licencia**: **MIXTA** (CC0, CC-BY, CC-BY-NC). Filtra por CC0 explícitamente.
- **Catálogo**: enorme (~600k samples). Lo más completo de internet.
- **Cuidado**: muchos son CC-BY (atribución requerida — ten archivo de créditos).
- **Útil para**: sonidos específicos que Kenney no cubre (gunshots reales, voces, ambientes naturales).

### Pixabay Music — <https://pixabay.com/music>
- **Licencia**: Pixabay (CC0-like)
- **Útil para**: música de fondo libre de royalties.

### Sonniss — <https://sonniss.com/gameaudiogdc>
- **Licencia**: licencia comercial gratis (drops anuales en GDC)
- **Calidad**: profesional (estudios de Hollywood). Cientos de GB.
- **Útil para**: cuando el juego empiece a necesitar audio AAA.

### Bfxr — <https://www.bfxr.net>
- **Licencia**: lo que generes es tuyo
- **Tipo**: generador procedural de sfx 8-bit/16-bit (estilo retro).
- **Útil para**: prototipar UI sounds, pickups, blips sin descargar nada.

---

## Modelos 3D

### Poly Haven Models — <https://polyhaven.com/models>
- **Licencia**: CC0
- **Formatos**: .blend, .fbx, .gltf, .glb, .usd
- **Útil para**: props de mundo (sillas, mesas, plantas, vehículos).

### Quaternius — <https://quaternius.com>
- **Licencia**: CC0
- **Estilo**: low-poly stylized. Packs temáticos (Ultimate RPG, Modular Buildings, Animated Animals).
- **Útil para**: characters animados con esqueleto + animaciones (caminar, correr, atacar). El **Animated Animals** pack incluye un capybara low-poly riggeado 🦫.

### Kenney.nl Models — <https://kenney.nl/assets/category:3D>
- **Licencia**: CC0
- **Estilo**: chunky low-poly (estilo "Minecraft con bordes redondeados").
- **Packs**: weapons, characters, vehicles, props.

### Sketchfab Free — <https://sketchfab.com/store?features=downloadable&price=free>
- **Licencia**: **MIXTA**. Filtra por "Downloadable" + "CC0/CC-BY".
- **Catálogo**: enorme, calidad variable.
- **Útil para**: assets específicos no encontrados en otros sitios.

### Mixamo — <https://www.mixamo.com>
- **Licencia**: gratis con cuenta de Adobe; uso comercial permitido.
- **Útil para**: rigear automáticamente un mesh y aplicarle 1500+ animaciones de mocap (caminar, correr, disparar, recargar, morir).
- **Workflow**: subes .fbx sin riggear → Mixamo lo riggea + animaciones → descargas .fbx con esqueleto humanoid.

### Itch.io Free Assets — <https://itch.io/game-assets/free>
- **Licencia**: **MIXTA** — filtra por licencia.
- **Útil para**: art packs indie temáticos (cyberpunk, fantasy, sci-fi).

---

## Fuentes (typography)

### Google Fonts — <https://fonts.google.com>
- **Licencia**: Open Font License (uso comercial libre).
- **Útil para**: UI fonts. Filtra por "Display" para títulos, "Monospace" para código/HUD.

### Font Squirrel — <https://www.fontsquirrel.com>
- **Licencia**: revisa cada fuente (mayoría free for commercial).
- **Útil para**: typography specializada (military stencil, gothic, retro).

---

## VFX (partículas, shaders)

### Godot Shaders — <https://godotshaders.com>
- **Licencia**: MIT en su mayoría
- **Útil para**: efectos visuales drop-in (water, fire, dissolve, outlines, toon shading).

### OpenGameArt — <https://opengameart.org>
- **Licencia**: **MIXTA** (CC0, CC-BY, GPL...). Filtra explícitamente.
- **Útil para**: VFX 2D (explosion sprites, particle textures), spritesheets, tilesets.

---

## Cómo añadir un asset al proyecto

1. Verifica la licencia (compatible con CC0 idealmente).
2. Descarga al folder correspondiente en `assets/`:
   - `assets/textures/<categoria>/`
   - `assets/audio/<sfx|music|voice>/`
   - `assets/models/`
   - `assets/fonts/`
3. Si pesa >1 MB, considera Git LFS (`git lfs track "*.png"`).
4. Añade entrada a `assets/CREDITS.md` con: archivo, fuente, URL, licencia, autor (si CC-BY).
5. Re-importa en Godot (cierra y abre el proyecto, o "Reimport" en FileSystem).

## Workflow recomendado para texturas PBR

1. Bajar **diffuse + normal** mínimo (roughness y AO si quieres más PBR-correcto).
2. Aplicar en `StandardMaterial3D` con `albedo_texture` + `normal_enabled = true` + `normal_texture`.
3. Activar **`uv1_triplanar = true`** para boxes/cilindros sin UV custom — proyecta desde 3 ejes y evita stretching.
4. `uv1_scale` controla el tamaño del tile. `1.0` = una repetición por metro en mundo. `0.3` = una cada ~3.3m (más sutil).
5. Para superficies muy grandes (suelo de 100m), bajar `uv1_scale` a 0.2-0.5 y subir `roughness` a ~0.9 para evitar tile pattern obvio.

## Recursos extra

- **Lista mantenida por Godot**: <https://docs.godotengine.org/en/stable/community/asset_library/index.html>
- **Awesome Godot**: <https://github.com/godotengine/awesome-godot> (incluye sección de assets)
- **CC0 Textures Mega-list**: <https://github.com/ellisonleao/awesome-cc0> (muchas fuentes adicionales)
