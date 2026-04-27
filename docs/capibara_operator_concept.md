# CONCEPT DOCUMENT — "Capibara Operator"

*Cartoon estilizado · Halo-inspired · Post-apocalíptico futurista*
*Perspectiva: 3ª persona*

---

## 1. Identidad del personaje

- **Nombre código sugerido**: Operator C-7 / "Capi"
- **Arquetipo**: Soldado de élite tipo Spartan, pero con la silueta robusta y baja del capibara → contraste visual cómico-serio.
- **Personalidad visual**: Estoico, veterano, ligeramente desgastado por la guerra. NO comic relief — su seriedad ES el chiste.
- **Silueta clave**: Cuerpo bajo y ancho (proporciones reales del capibara: 4 patas cortas, torso cilíndrico, cabeza grande y cuadrada). El traje exagera esa robustez = parece un tanque andante.

## 2. Anatomía y proporciones

- **Postura**: Bípedo (camina en 2 patas para sostener armas). Las patas traseras se han adaptado con exoesqueleto.
- **Altura**: ~1.4m de pie (más bajo que un humano, más imponente por el ancho).
- **Cabeza**: Grande, ocupa ~1/4 del cuerpo. Hocico chato, orejas pequeñas redondas, ojos pequeños y oscuros.
- **Manos**: Garras adaptadas con guantes táctico-mecánicos de 4 dedos para empuñar armas.
- **Cola**: Inexistente o vestigial (los capibaras no tienen cola visible — mantener fiel).

## 3. Traje táctico (el "MJOLNIR Capibara")

### Estructura por zonas

| Zona | Descripción |
|---|---|
| **Casco** | Visor cuadrado tipo ODST/Master Chief adaptado al hocico chato. Visor naranja-ámbar emisivo, HUD interno visible como reflejos. Antena táctica corta lateral. |
| **Pectoral** | Placa pesada con paneles modulares, hebillas magnéticas, número "C-7" estarcido en blanco descolorido. |
| **Hombreras** | Sobredimensionadas, asimétricas: la izquierda más grande (placa de blindaje extra con rasguños/impactos), la derecha con porta-granadas. |
| **Brazos** | Mangas de tejido balístico gris oscuro + codera mecánica. Antebrazo izquierdo: pantalla holográfica táctica (verde fosforescente, tipo TACPAD). |
| **Guantes** | Tácticos negros con refuerzos metálicos en nudillos. |
| **Cintura/cinturón** | Cinturón utility con 4-5 pouches, funda de pistola en cadera derecha, vaina de cuchillo en cadera izquierda. |
| **Piernas** | Pantalón cargo balístico + rodilleras blindadas + botas exoesqueléticas con servos visibles a los lados. |
| **Mochila** | Backpack táctico bajo con luz LED roja parpadeante y porta-rifle magnético en la espalda. |

### Materiales (clave para el prompt de IA)

- **Placas duras**: Plástico/cerámica mate con sutil grano, NO metal pulido. Estilo Halo: pintura desgastada, no realismo extremo.
- **Tejidos**: Mate, sin brillo, con costuras visibles.
- **Detalles emisivos**: Naranja ámbar (visor) + verde fósforo (HUD/pantalla brazo) + rojo (luz mochila).
- **Desgaste**: Rasguños, polvo, pintura saltada en bordes. NO sangre ni daño extremo — veterano, no destruido.

## 4. Paleta de colores

```
PRIMARIO    Verde oliva militar desaturado    #4A5240
SECUNDARIO  Gris carbón                       #2B2D2E
ACENTO 1    Naranja ámbar emisivo (visor)     #FF8C2A
ACENTO 2    Verde fósforo HUD                 #7FFF5A
ACENTO 3    Rojo señalización                 #D43838
NEUTROS     Beige polvo / ocre desierto       #B8A179
PIEL        Marrón capibara cálido            #8B6F47
```

Ratio recomendado: 60% verde oliva + 25% gris carbón + 10% beige polvo + 5% acentos emisivos.

## 5. Repertorio de armas

### ARMA 1 — Cuchillo táctico "K-Bayonet C7"

- **Tipo**: Cuchillo de combate / utility.
- **Forma**: Hoja recta de ~20cm, tipo tanto militar, con filo aserrado en el lomo posterior.
- **Material**: Hoja de cerámica negra mate (no refleja), mango polímero gris con grip texturizado naranja.
- **Detalle futurista**: Línea emisiva ámbar tenue corriendo por el centro del filo (monomolecular vibroblade).
- **Slot**: Vaina en cadera izquierda, montaje magnético.
- **Stats sugeridos** (Godot): Daño 40, alcance 1.5m, cooldown 0.4s, sin munición.

### ARMA 2 — Pistola "M6-K Sidearm"

- **Tipo**: Pistola semiautomática pesada (inspiración: M6 Magnum de Halo + Glock 17).
- **Forma**: Cuerpo angular y robusto, cañón cuadrado, cargador grueso.
- **Tamaño**: Compacta pero pesada, ajustada a las manos pequeñas del capibara (~22cm largo).
- **Detalles**:
  - Riel superior con mira reflex pequeña (punto rojo emisivo).
  - Linterna táctica integrada bajo el cañón.
  - Acabado verde oliva mate con detalles negros.
  - Cargador con LED indicador de munición (verde → ámbar → rojo).
- **Stats sugeridos**: Daño 25, cargador 12 balas, recarga 1.2s, cadencia 300rpm, precisión alta.

### ARMA 3 — Rifle de asalto "MA5C-K Assault Rifle"

- **Tipo**: Rifle de asalto bullpup futurista (inspiración directa: MA5 de Halo).
- **Forma**: Compacto, cuerpo rectangular con pantalla de munición digital en la parte superior, culata corta.
- **Detalles**:
  - Pantalla LCD verde fósforo en el lomo (contador de munición visible).
  - Cañón con supresor cuadrado integrado.
  - Empuñadura vertical frontal.
  - Cargador curvo de alta capacidad debajo.
  - Acabado bicolor: cuerpo gris carbón + paneles verde oliva + sello "UNSC-K" estarcido (o tu propia facción).
- **Slot**: Magnético en la espalda cuando no está en uso.
- **Stats sugeridos**: Daño 18, cargador 32 balas, recarga 2.0s, cadencia 600rpm, precisión media.

## 6. Setting / contexto visual (para fondos)

Ciudad futurista post-apocalíptica:

- Rascacielos parcialmente colapsados con estructuras expuestas.
- Vegetación recuperando el terreno (raíces, musgo, enredaderas — guiño al hábitat acuático/selvático del capibara real).
- Carteles holográficos rotos parpadeando.
- Charcos de agua estancada (ambiente capibara-friendly).
- Cielo naranja-marrón polvoriento o gris tormentoso.
- Vehículos militares oxidados, contenedores de carga, barricadas.

---

## 7. PROMPTS LISTOS PARA USAR

### Prompt MAESTRO (Midjourney v7 / Flux.1) — Character sheet

```
Character concept sheet, stylized cartoon 3D render, Halo-inspired
military sci-fi aesthetic, anthropomorphic capybara soldier standing
upright on hind legs, wearing heavy futuristic tactical armor with
matte olive green and charcoal panels, oversized asymmetric pauldrons,
square ODST-style helmet visor glowing amber-orange adapted to flat
capybara snout, modular chest plate with stencil "C-7", utility belt
with pouches, exoskeleton boots with visible servos, holographic
phosphor-green tacpad on left forearm, weathered paint with battle
scratches, stoic veteran pose, three quarter front view, neutral grey
studio background, soft rim lighting, character turnaround style,
clean cartoon shading with subtle PBR materials, Overwatch meets Halo
art direction, high detail, no text
--ar 3:4 --style raw --stylize 250
```

### Prompt para las 3 armas (genera las tres en una imagen)

```
Three futuristic military weapons displayed on neutral grey background,
weapon concept sheet, Halo art style, stylized cartoon 3D render:
1) Tactical combat knife with black ceramic blade, polymer grip with
orange texture, faint amber glowing line along blade center,
2) Heavy semi-automatic pistol M6-style, angular boxy body, olive green
matte finish, integrated tactical flashlight, small red dot reflex sight,
LED ammo indicator on magazine,
3) Bullpup assault rifle MA5-inspired, rectangular body with green
phosphor LCD ammo counter on top, integrated square suppressor, vertical
foregrip, curved high-capacity magazine, charcoal and olive bicolor
finish, "UNSC-K" stencil markings.
Studio product shot lighting, weathered paint with scratches, top-down
and side view orthographic, clean cartoon shading
--ar 16:9 --style raw --stylize 200
```

### Prompt para escena ambiental (key art)

```
Anthropomorphic capybara soldier in heavy tactical armor walking through
ruined futuristic city, post-apocalyptic atmosphere, collapsed
skyscrapers overgrown with vines and moss, broken holographic billboards
flickering, dusty orange-brown sky, stagnant water puddles reflecting
amber visor glow, holding bullpup assault rifle, cinematic third person
game key art, Halo Reach mood, stylized cartoon render, dramatic rim
lighting, volumetric dust
--ar 16:9 --style raw --stylize 300
```

## 8. Pipeline recomendado a Godot

1. **Midjourney/Flux** → genera 4 imágenes: turnaround del personaje (frente, perfil, espalda, 3/4) + armas + key art.
2. **Selecciona la mejor vista frontal limpia** del personaje.
3. **Meshy.ai** → "Image to 3D" → ajusta a estilo *stylized*, exporta `.glb` con rig automático.
4. **Para cada arma**: mismo proceso, exporta `.glb` por separado.
5. **En Godot**:
   - Importa el capibara como `CharacterBody3D`.
   - Crea `Node3D` hijos como `attach_points` (mano derecha, mano izquierda, espalda, cadera izq, cadera der).
   - Cada arma es un `Resource` (`Weapon.tres`) con stats + referencia a su `.glb`.
   - Sistema de equipar = mover el `.glb` al attach point correcto + actualizar `current_weapon`.

## 9. Referencias visuales

- **Halo: Reach** — armadura ODST, paleta, mood post-apocalíptico.
- **Overwatch** — shading cartoon estilizado con PBR sutil.
- **Apex Legends** — proporciones exageradas de armas y armadura.
- **Helldivers 2** — desgaste militar y paleta verde oliva.
- **Beastars / Zootopia** — proporciones antropomórficas (NO estilo).
