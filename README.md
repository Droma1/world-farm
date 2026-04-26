# worldFarm — Capybara Combat Training (Shooter en Godot 4.6)

Proyecto de un juego **shooter** desarrollado en **Godot 4.6** (3D, Jolt Physics, Forward+).
Single-player con sistema de oleadas; arquitectura preparada para escalar a **multiplayer autoritativo de servidor** sin reescribir la base.

**Personaje principal**: capibara antropomórfico armado con rifle de asalto 🦫🔫.
**Estilo visual**: stylized / cel-shaded (toon shading + colores saturados, look tipo Fortnite).

> Este README es a la vez **guía de arquitectura** y **estado del proyecto**. Si estás retomando el desarrollo, empieza por la sección 0 ("Estado actual") y vuelve a la 11 ("Roadmap") para ver qué sigue.

---

## Tabla de contenidos

0. [**Estado actual y cómo retomar**](#0-estado-actual-y-cómo-retomar) ⬅ empieza aquí si vuelves
1. [Filosofía del proyecto](#1-filosofía-del-proyecto)
2. [Stack técnico](#2-stack-técnico)
3. [Arquitectura general](#3-arquitectura-general)
4. [Estructura de carpetas](#4-estructura-de-carpetas)
5. [Convenciones de código y nombrado](#5-convenciones-de-código-y-nombrado)
6. [Sistemas del juego](#6-sistemas-del-juego)
7. [Cómo crear un personaje (paso a paso)](#7-cómo-crear-un-personaje-paso-a-paso)
8. [Cómo crear un elemento / item / arma](#8-cómo-crear-un-elemento--item--arma)
9. [Integración entre sistemas](#9-integración-entre-sistemas)
10. [Plan de migración a multiplayer](#10-plan-de-migración-a-multiplayer)
11. [Roadmap por fases](#11-roadmap-por-fases)
12. [Glosario](#12-glosario)

---

## 0. Estado actual y cómo retomar

### TL;DR del juego (lo que tienes hoy)

Abre el proyecto en Godot 4.6 → `F5` → arrancas en el **menú principal**. Pulsa **JUGAR** y entras al `TrainingMap`:

- **4 oleadas** con dificultad escalada (3 grunts → 4 grunts + 1 heavy → 2 snipers + 2 grunts → 5 grunts + 2 heavies + 2 snipers).
- **3 tipos de enemigo**: Grunt (60 HP, score 100), Heavy (180 HP lento, score 300), Sniper (35 HP largo alcance, score 200). Spawnean ya en modo CHASE, persiguen via NavigationAgent3D.
- **AI con strafe**: en estado ATTACK los enemigos dan pasos laterales aleatorios cada 1.5-3s.
- **Pickups**: HealthPickup (+30 HP) y AmmoPickup (+30 munición) que dropean enemigos al morir según `drop_chance`.
- **Kill streak**: cadenas de kills <3s entre sí dan multiplicador (x1.5, x2.0, ... tope x4.0). Recibir daño rompe la streak.
- **HUD completo**: vida, ammo, nombre del arma, score, streak, oleada, contador de enemigos, crosshair con hit-marker, vignette de daño, números flotantes de daño.
- **Pause menu** (Esc) con sliders de sensibilidad y volumen, persistidos en `user://settings.cfg`.
- **Game over / Victoria**: overlay con animación de muerte (capibara cae hacia atrás), R para retry o M para menú.

### Controles

| Input | Acción |
|-------|--------|
| `WASD` | Mover |
| `Mouse` | Mirar (TPS over-the-shoulder) |
| `Click izq.` | Disparar |
| `Click der.` | Toggle ADS (zoom 35° FOV) |
| `Rueda mouse` | Zoom continuo (clamp 20°-80°) |
| `X` | Reset de zoom |
| `Shift` | Sprint |
| `Ctrl` | Agacharse (la cápsula encoge — pasas por el túnel sur) |
| `Space` | Saltar |
| `R` | Recargar |
| `1` / `2` | Cambiar entre rifle / pistola (mantienen ammo state) |
| `Q` | Toggle rápido al arma anterior |
| `Esc` | Pausar |
| `R` (en game over/victoria) | Reintentar |
| `M` (en game over/victoria) | Volver al menú |

### Cómo retomar el desarrollo

1. Abre Godot 4.6 → "Import Project" → carpeta del repo.
2. Espera a que importe los assets (~5s, especialmente la primera vez con los `.png` y `.jpg` de `assets/`).
3. **Si las texturas no se ven al `F5`**: cierra y reabre Godot, o en `FileSystem` panel click derecho → "Reload Saved Scene" en `TrainingMap.tscn`.
4. **Antes de tocar código**: lee §3 (Arquitectura general) y §11 (Roadmap actualizado) — sabrás qué está hecho y qué sigue.
5. **Convención**: cuando añadas un nuevo sistema, va en `scripts/systems/<nombre>/`, expone API por signals + métodos públicos, NO importa otros sistemas (usa `EventBus` para eventos cross-cutting).

### Visual style — Fortnite-like

El look es **cel-shaded / toon**:
- Materiales con `diffuse_mode = 3` (DIFFUSE_TOON) y `specular_mode = 1` (SPECULAR_TOON) — luz en pasos discretos en vez de gradiente suave.
- Colores `albedo_color` saturados, sin texturas diffuse en el mapa (solo flat colors por superficie).
- Player capibara mantiene textura `leather_white` tinteada de marrón como sustituto de pelaje.
- Rifle mantiene textura sutil para diferenciarlo del entorno plano.
- Para más detalle ver [`docs/ASSET_SOURCES.md`](docs/ASSET_SOURCES.md) → sección "🎮 Estilo Fortnite / Stylized".

### Assets

- `assets/textures/proto/` — Kenney prototype (CC0)
- `assets/textures/pbr/` — Poly Haven PBR realistas (CC0) — usadas en Player/Rifle, NO en mapa actual
- `assets/audio/sfx/` — Kenney sci-fi sounds (CC0): shoot, impact, footstep, reload
- Créditos completos: [`assets/CREDITS.md`](assets/CREDITS.md)
- Fuentes recomendadas para añadir más: [`docs/ASSET_SOURCES.md`](docs/ASSET_SOURCES.md)

### Quick troubleshooting

| Síntoma | Causa probable | Fix |
|---------|----------------|-----|
| Texturas no se ven (todo gris/flat) | `.tscn` cacheado en Godot abierto | Cerrar y reabrir Godot |
| Enemigos no se mueven | Spawn fuera de detection_range | Confirma que `EnemyAI._ready` setea `state = CHASE` si hay `local_player` |
| Errores `class_name not found` | Reorden circular de ext_resources | Forzar reimport: borra `.godot/`, reabre proyecto |
| Sin sonido | `Settings.master_volume = 0` persistido | Pause menu → subir slider, o borrar `user://settings.cfg` |
| Capibara muere y no pasa nada | OK — la animación de caída tarda 1.1s antes del overlay | Espera; o revisa `Player._on_died` |

---

---

## 1. Filosofía del proyecto

Tres principios que mandan sobre cualquier decisión técnica:

- **Modularidad estricta.** Cada sistema (disparo, inventario, salud, IA…) vive en su carpeta, expone una API por *signals* y *métodos públicos*, y **no** conoce a los demás sistemas. Si dos sistemas necesitan hablar, lo hacen por un **EventBus** o por un *signal* del nodo padre. Esto permite reemplazar o testear un sistema en aislamiento.
- **Composición por encima de herencia.** En lugar de una clase `PlayerEnemyShooter` con todo dentro, los entes son `Node3D` que **componen** *components* (`HealthComponent`, `WeaponComponent`, `HitboxComponent`, etc.). Es el patrón ECS-light que mejor encaja con Godot.
- **Datos como Resources, no como código.** Las stats de un arma, las propiedades de un item o las definiciones de enemigos viven en archivos `.tres` (Godot Resources). El código solo *lee* esos datos. Cambiar balance no debe requerir tocar `.gd`.

Bonus, pero igual de importante:

- **Server-authoritative ready.** Toda lógica de juego (daño, hit detection, inventario) se escribe asumiendo que mañana correrá en un servidor y el cliente solo *predice* y *renderiza*. No mezclar input con lógica de mundo.
- **Determinismo donde se pueda.** Evitar `randf()` directo en lógica crítica; usar un `RandomNumberGenerator` con seed por partida. Facilita debug, replays y netcode.

---

## 2. Stack técnico

| Capa | Elección | Por qué |
|------|----------|---------|
| Motor | **Godot 4.6** | Open source, GDScript ergonómico, buen soporte 3D y multiplayer nativo (`MultiplayerAPI`, `MultiplayerSynchronizer`). |
| Física | **Jolt Physics** (ya configurado) | Más rápida y estable que la default en escenas con muchos rigidbodies y CharacterBody3D. |
| Renderizado | **Forward+** (ya configurado) | Mejor calidad visual, soporta más luces dinámicas. Backend D3D12 en Windows. |
| Lenguaje | **GDScript** (principal) + **C#** opcional para hot paths | GDScript es suficiente para el 95%. C# solo si profiling lo justifica. |
| Networking (fase 2) | **ENet** (UDP) vía `MultiplayerAPI` | Default de Godot, fiable para FPS hasta ~32 jugadores. |
| Tests | **gdUnit4** (addon) | Tests unitarios para sistemas críticos (daño, inventario, RNG). |
| Control de versiones | **Git** + LFS para binarios pesados (`*.glb`, `*.png` >1MB, audio) | Evitar inflar el repo. |

---

## 3. Arquitectura general

El juego se organiza en **cuatro capas**:

```
┌─────────────────────────────────────────────────────┐
│  CAPA 4 — PRESENTACIÓN  (UI, HUD, cámaras, audio)   │
├─────────────────────────────────────────────────────┤
│  CAPA 3 — ENTIDADES     (Player, Enemy, Pickup)     │
│            compuestas por Components                │
├─────────────────────────────────────────────────────┤
│  CAPA 2 — SISTEMAS      (Combat, Inventory, AI…)    │
│            independientes, comunicados vía EventBus │
├─────────────────────────────────────────────────────┤
│  CAPA 1 — NÚCLEO        (Autoloads / Singletons)    │
│            EventBus, GameState, Settings, RNG, Net  │
└─────────────────────────────────────────────────────┘
```

### 3.1. Núcleo: Autoloads (Singletons)

Los *Autoloads* son nodos cargados al arrancar el juego, accesibles desde cualquier script por nombre. Se registran en `Project Settings > Autoload`. Definimos:

- `EventBus` — *signals* globales (`enemy_died`, `player_damaged`, `item_picked_up`). Sistemas se suscriben sin acoplarse entre sí.
- `GameState` — estado global de la partida (puntuación, ronda actual, modo de juego, jugadores conectados).
- `Settings` — configuración del usuario (volumen, sensibilidad, keybindings) persistida en `user://settings.cfg`.
- `RNG` — `RandomNumberGenerator` con seed por partida; cualquier aleatoriedad de gameplay pasa por aquí.
- `SaveSystem` — serialización a JSON/binario en `user://saves/`.
- `NetworkManager` (fase 2) — wrapper sobre `MultiplayerAPI`: host, join, sync, RPCs.

> **Regla de oro:** los Autoloads NO contienen lógica de gameplay. Son *infraestructura*. Si te encuentras escribiendo `if enemy.health <= 0:` dentro de un autoload, vuelve a leer esta línea.

### 3.2. Sistemas

Un *sistema* es una carpeta en `scripts/systems/<nombre>/` con:

- Una API pública (clase principal o un nodo singleton local).
- *Signals* para notificar eventos (`shot_fired`, `reload_started`).
- *Resources* para configuración (`weapon_data.tres`).
- Cero referencias hardcoded a otros sistemas.

Si el sistema de combate necesita reducir vida del jugador, **no** llama a `player.health -= dmg`. Emite `EventBus.damage_dealt.emit(target, amount, source)` y el `HealthComponent` del target lo escucha. Así un mod, un test o un servidor puede interceptar ese flujo.

### 3.3. Entidades y Components

Una *entidad* (Player, Enemy, Pickup) es un `Node3D` (o `CharacterBody3D`) con sub-nodos *Component*. Cada Component es un script con responsabilidad única.

Ejemplo: el Player es:

```
Player (CharacterBody3D)
├── MeshInstance3D
├── CollisionShape3D
├── Camera3D (con SpringArm3D para 3ª persona, opcional)
├── HealthComponent       # vida, daño recibido, muerte
├── MovementComponent     # walk/run/jump, input
├── WeaponComponent       # arma equipada, disparar
├── InventoryComponent    # items en mochila
├── HitboxComponent       # área que recibe daño
└── HurtboxComponent      # área que inflige daño melee
```

**Ventaja:** un Enemy reutiliza `HealthComponent` y `HitboxComponent` exactos del Player. Cero duplicación.

---

## 4. Estructura de carpetas

```
res://
├── addons/                 # plugins de terceros (gdUnit4, dialogue manager…)
├── assets/                 # recursos crudos (importables)
│   ├── audio/
│   │   ├── music/
│   │   ├── sfx/            # disparos, pasos, impactos
│   │   └── voice/
│   ├── fonts/
│   ├── materials/          # .tres de StandardMaterial3D
│   ├── models/             # .glb / .gltf
│   ├── shaders/            # .gdshader
│   └── textures/
├── docs/                   # documentación adicional, diagramas, ADRs
├── resources/              # datos del juego (.tres) — NO código
│   ├── characters/         # CharacterData (stats base de cada personaje)
│   ├── enemies/            # EnemyData (IA, loot table, stats)
│   ├── items/              # ItemData (consumibles, ammo, key items)
│   ├── weapons/            # WeaponData (daño, cadencia, recoil, sfx)
│   └── levels/             # LevelData (spawn points, oleadas)
├── scenes/                 # composición visual (.tscn)
│   ├── characters/
│   │   ├── player/         # Player.tscn + variantes
│   │   └── enemies/
│   ├── components/         # Component.tscn reutilizables
│   ├── effects/            # explosiones, partículas, decals
│   ├── levels/             # mapas jugables
│   ├── ui/                 # HUD, menús, pantallas
│   ├── weapons/            # modelos de armas en mano
│   └── world/              # props, pickups, doors
├── scripts/                # lógica (.gd)
│   ├── autoload/           # EventBus.gd, GameState.gd, RNG.gd, …
│   ├── components/         # HealthComponent.gd, WeaponComponent.gd, …
│   ├── entities/           # Player.gd, Enemy.gd, Pickup.gd
│   ├── resources/          # clases que extienden Resource (WeaponData.gd…)
│   ├── systems/
│   │   ├── combat/         # cálculo de daño, hit detection
│   │   ├── input/          # mapeo de input, dispositivos
│   │   ├── inventory/      # lógica de mochila, stacks, hotbar
│   │   ├── networking/     # (fase 2) sincronización, RPC, lobby
│   │   ├── save/
│   │   ├── spawning/       # oleadas, spawn points
│   │   └── ai/             # state machines, percepción
│   ├── ui/
│   └── utils/              # helpers genéricos (Math, Debug, …)
└── tests/                  # gdUnit4
    ├── unit/
    └── integration/
```

**Regla práctica:** `scenes/` y `scripts/` espejan la misma jerarquía. Si tienes `scenes/characters/player/Player.tscn`, su script vive en `scripts/entities/Player.gd` (no dentro de `scenes/`). Esto evita que mover una escena rompa imports y facilita revisiones de PR.

---

## 5. Convenciones de código y nombrado

### Archivos
- Escenas y scripts de **clases**: `PascalCase` → `WeaponComponent.gd`, `Player.tscn`.
- Recursos `.tres`: `snake_case` → `pistol_basic.tres`, `enemy_grunt.tres`.
- Carpetas: `snake_case` siempre.

### Código GDScript
- Variables y funciones: `snake_case`.
- Constantes y enums: `SCREAMING_SNAKE_CASE`.
- Clases custom: `class_name PascalCase` siempre arriba (permite usarlas como tipo).
- Tipado **siempre** en variables de instancia y firmas de función:
  ```gdscript
  var current_health: float = 100.0
  func take_damage(amount: float, source: Node) -> void:
  ```
- Signals: pasado simple, descriptivo → `damaged`, `died`, `weapon_fired`, `item_picked_up`.

### Comentarios
- Solo cuando el *por qué* no es obvio. No documentar lo que el nombre ya dice.
- `# TODO:` solo con autor e issue → `# TODO(nando): #42 corregir hitscan en techos`.

---

## 6. Sistemas del juego

Cada sistema se construye **en aislamiento** primero (con una escena de test propia en `tests/integration/`), y se integra al resto solo cuando pasa sus tests.

### 6.1. Sistemas core (MVP — fase 1)

Estado: ✅ implementado · 🟡 implementado parcialmente · ⏳ pendiente

| Sistema | Estado | Ubicación real | Notas de implementación |
|---------|--------|----------------|-------------------------|
| **Input** | ✅ | `autoload/InputSetup.gd` | Acciones registradas en runtime (move_forward/back/left/right, jump, sprint, crouch, fire, aim, reload, zoom_reset) usando `physical_keycode`. No hay rebinding UI todavía. |
| **Movement** | ✅ | `components/MovementComponent.gd` | WASD, sprint, crouch (encoge cápsula colisión con lerp), jump. Footsteps signal. AI/NPC usan `read_input = false` + `external_wish_dir`. |
| **Camera** | ✅ | en `Player.tscn` | TPS over-the-shoulder. Pitch + body yaw. SpringArm3D. Recoil pivot separado del pitch (decay). Shake al daño. Zoom (rueda mouse / right-click ADS toggle). FOV lerp. |
| **Combat / Shooting** | ✅ | `components/WeaponComponent.gd` + `components/WeaponVFX.gd` | Hitscan con spread aleatorio. Cooldown por RPM. Modos SEMI/AUTO/BURST. Tracer + decals + sparks + muzzle flash. |
| **Health & Damage** | ✅ | `components/HealthComponent.gd` | take_damage / heal / died signals. |
| **Inventory** | 🟡 | en `Player.gd` directamente | Player tiene `Array[WeaponData]` + ammo state preservado al swap. Falta inventario general (consumibles, key items). |
| **Weapon** | ✅ | `components/WeaponComponent.gd` + `resources/weapons/*.tres` | rifle_basic, rifle_enemy, rifle_sniper, pistol_basic. Player swap con 1/2/Q. |
| **Pickup / Loot** | ✅ | `entities/Pickup.gd` + `HealthPickup` + `AmmoPickup` | Area3D con hover/spin. Enemy droppea según `EnemyData.drop_chance`. EventBus.pickup_collected → HUD feedback. |
| **AI / Enemy** | ✅ | `components/EnemyAI.gd` | State machine IDLE→CHASE→ATTACK→DEAD. NavigationAgent3D para pathfinding. LOS check via raycast. Strafe en ATTACK. Empieza CHASE si hay player. |
| **Spawning / Waves** | ✅ | `systems/spawning/WaveSystem.gd` + `WaveData` | 4 oleadas con tipos mezclados (Array[EnemyData] paralelo a counts). Timer entre oleadas. Pausa con `GameState.mode != PLAYING`. |
| **UI / HUD** | ✅ | `ui/HUD.gd` + `MainMenu.gd` | Crosshair + hit marker + health + ammo + reload + score + streak + wave + damage vignette + end overlay + pause menu + main menu con sliders. |
| **Audio** | ✅ | `autoload/AudioManager.gd` | `STREAM_VARIATIONS` dict con randomización. Suscripto a EventBus.weapon_fired/impact. AudioStreamPlayer3D con atenuación. Footsteps via `MovementComponent.step` signal. |
| **VFX** | ✅ | `components/WeaponVFX.gd` + `systems/vfx/DamageNumbers.gd` | Muzzle flash, tracer, bullet hole decal (QuadMesh con tween), sparks (CPUParticles3D), camera shake, weapon kick visual. Damage numbers flotantes (Label3D billboard). |
| **Score / Streak** | ✅ | `autoload/GameState.gd` | Score con setter + signal. Kill streak (3s ventana, x1.5/2.0/2.5/... tope x4.0). Reset al recibir daño. |
| **GameState / Round** | ✅ | `autoload/GameState.gd` | Mode enum (MENU/PLAYING/PAUSED/GAME_OVER/VICTORY) con signal. Local_player ref. |
| **Settings** | ✅ | `autoload/Settings.gd` | Persiste mouse_sensitivity, master_volume, sfx_volume en `user://settings.cfg`. Aplica a AudioServer y a Player (via signal). |
| **Save / Load** | 🟡 | solo Settings | Settings persistidas. Falta savegame de progreso/score/unlocks. |

### 6.2. Sistemas a añadir (fase 2+)

| Sistema | Por qué importa |
|---------|-----------------|
| **Networking** | Multiplayer autoritativo de servidor (ver §10). |
| **Lobby & Matchmaking** | Crear/unirse a partidas, listas, ready-up. |
| **Replication / Interpolation** | Suavizar movimiento de jugadores remotos. |
| **Anti-cheat ligero** | Validación server-side de daños y velocidades. |
| **Localization** | Strings en `*.po` o `*.csv`, soporte vía `tr("KEY")`. |
| **Quest / Objectives** | Misiones por mapa, triggers, progreso. |
| **Progression / Skill tree** | XP, niveles, perks, unlocks de armas. |
| **Achievements** | Logros locales o vía Steam (GodotSteam addon). |
| **Telemetry / Analytics** | Eventos a un backend para balance (KDA, armas más usadas). |
| **Replay system** | Posible si el RNG y el input están bien encapsulados. |
| **Modding API** | Cargar `.pck` externos con armas / mapas custom. |
| **Accessibility** | Subtítulos, daltonismo, escalado de UI, asistente de puntería. |

> **Cuándo añadir cada uno:** no antes de que el sistema previo esté **estable y testeado**. Añadir networking sobre un Combat con bugs multiplica los bugs por 10.

---

## 7. Cómo crear un personaje (paso a paso)

> Ejemplo: vamos a crear el `Player`. Para un `Enemy` es exactamente igual, cambiando el `MovementComponent` por un `AIController`.

### Paso 1 — Definir los datos (Resource)

Crea `scripts/resources/CharacterData.gd`:

```gdscript
class_name CharacterData
extends Resource

@export var display_name: String = "Player"
@export var max_health: float = 100.0
@export var move_speed: float = 5.0
@export var jump_velocity: float = 6.0
@export var mesh_scene: PackedScene
@export var starting_weapon: WeaponData
```

Luego en el editor: `Right click > New Resource > CharacterData` → `resources/characters/player_default.tres`. Rellenas valores y *no tocas código* para balancear.

### Paso 2 — Componer la escena

`scenes/characters/player/Player.tscn`:

```
Player (CharacterBody3D)         ← script: Player.gd
├── Visuals (Node3D)             ← aquí instanciar mesh_scene
├── CollisionShape3D
├── Camera3D (o SpringArm3D + Camera3D para 3ª persona)
├── HealthComponent              ← scripts/components/HealthComponent.gd
├── MovementComponent
├── WeaponComponent
├── InventoryComponent
├── HitboxComponent (Area3D)
└── InteractRay (RayCast3D)      ← para "press E to pick up"
```

### Paso 3 — Script del entity (delgado)

`scripts/entities/Player.gd`:

```gdscript
class_name Player
extends CharacterBody3D

@export var data: CharacterData

@onready var health: HealthComponent = $HealthComponent
@onready var movement: MovementComponent = $MovementComponent
@onready var weapon: WeaponComponent = $WeaponComponent

func _ready() -> void:
    health.max_health = data.max_health
    health.died.connect(_on_died)
    movement.configure(data.move_speed, data.jump_velocity)
    if data.starting_weapon:
        weapon.equip(data.starting_weapon)

func _on_died() -> void:
    EventBus.player_died.emit(self)
```

Fíjate: el entity **delega todo** a sus components. No implementa lógica directa.

### Paso 4 — Probar en aislamiento

Crea `tests/integration/player_sandbox.tscn` con un suelo, un dummy enemy, y el Player. Confirma:

- Se mueve con WASD.
- Pierde vida si lo dañan (puedes llamar `health.take_damage(10)` desde un botón debug).
- Dispara y el `EventBus.shot_fired` se emite (escúchalo con un `print`).

Solo cuando los 4 pasos funcionan, el Player se integra a un nivel real.

---

## 8. Cómo crear un elemento / item / arma

### 8.1. Item genérico (consumible, llave, munición)

`scripts/resources/ItemData.gd`:

```gdscript
class_name ItemData
extends Resource

enum ItemType { CONSUMABLE, AMMO, KEY, MATERIAL }

@export var id: StringName              # "medkit_small"
@export var display_name: String
@export var icon: Texture2D
@export var type: ItemType
@export var max_stack: int = 1
@export var pickup_scene: PackedScene   # cómo se ve en el mundo
@export var use_effect: ItemEffect      # otra Resource (curar, dar ammo, …)
```

Crear un medkit:
1. `Right click > New Resource > ItemData`.
2. `resources/items/medkit_small.tres`, rellenas valores.
3. Para que se pueda recoger del suelo, crea `scenes/world/Pickup.tscn` (genérico) con un `ItemData` exportado: el mismo Pickup sirve para *cualquier* item.

### 8.2. Arma

`scripts/resources/WeaponData.gd`:

```gdscript
class_name WeaponData
extends Resource

enum FireMode { SEMI, AUTO, BURST }
enum DamageType { HITSCAN, PROJECTILE }

@export var id: StringName
@export var display_name: String
@export_group("Damage")
@export var damage: float = 25.0
@export var headshot_multiplier: float = 2.0
@export var damage_type: DamageType = DamageType.HITSCAN
@export var projectile_scene: PackedScene  # solo si PROJECTILE
@export_group("Fire")
@export var fire_mode: FireMode = FireMode.SEMI
@export var rounds_per_minute: float = 600.0
@export var spread_degrees: float = 1.5
@export_group("Ammo")
@export var mag_size: int = 30
@export var reserve_ammo: int = 90
@export var reload_time: float = 2.0
@export_group("Feel")
@export var recoil_kick: Vector2 = Vector2(0.5, 0.2)
@export var camera_shake: float = 0.3
@export_group("Audio / Visual")
@export var fire_sound: AudioStream
@export var muzzle_flash: PackedScene
@export var view_model: PackedScene        # modelo del arma en mano
```

El `WeaponComponent` lee este recurso y se comporta. Cambiar de pistola a rifle = cambiar el `.tres`. Cero código.

---

## 9. Integración entre sistemas

El "pegamento" entre sistemas es el **EventBus**. Ejemplo del flujo de un disparo:

```
1. Input            → InputBuffer detecta "fire" press
2. WeaponComponent  → valida (ammo > 0, cooldown ok), consume bala
                    → emite EventBus.weapon_fired(weapon, origin, direction)
3. CombatSystem     → escucha weapon_fired
                    → hace raycast (hitscan) o spawnea projectile
                    → si impacta HitboxComponent → emite EventBus.damage_dealt(target, info)
4. HealthComponent  → escucha damage_dealt filtrado por target
                    → resta HP, emite damaged / died
5. UI / HUD         → escucha damaged → actualiza barra
6. VFX              → escucha weapon_fired → muzzle flash
                    → escucha damage_dealt → decal de impacto + sangre
7. Audio            → escucha weapon_fired → sfx de disparo 3D
8. AI               → escucha damage_dealt → si era enemigo, alertar a otros cerca
```

Ningún sistema importa a otro. Si mañana metes un sistema de **achievements**, solo se suscribe a `damage_dealt` y nadie más se entera.

---

## 10. Plan de migración a multiplayer

Decisiones que tomamos *ya* aunque no sea multiplayer:

1. **Sin `get_tree().root.find_node(...)`** ni *singletons mágicos* para alcanzar al jugador. Toda referencia se inyecta o se obtiene por *signal*. En multiplayer hay N jugadores; código que asume "el jugador" se rompe.
2. **Lógica de daño en un solo sitio.** El cliente no decide si murió: pide al servidor. Hoy ese "servidor" es el mismo proceso, mañana será otro.
3. **Input separado de la simulación.** El `InputBuffer` produce un `InputCommand` (struct serializable). En SP se aplica directo; en MP se envía al servidor.
4. **Estados replicables como datos puros.** Posición, vida, ammo. Animaciones y partículas son *cosméticas*, derivadas de estados.
5. **Tick fijo para gameplay.** `_physics_process` (60Hz por defecto) corre la lógica; `_process` solo cosas visuales. Esto encaja con netcode.

Cuando llegue la fase 2, el plan es:

1. Añadir `NetworkManager` autoload (host / join / disconnect).
2. Marcar el Player con `MultiplayerSynchronizer` para posición y rotación.
3. Convertir métodos críticos (`take_damage`, `equip_weapon`, `pick_up_item`) a `@rpc("any_peer", "call_local", "reliable")` validados server-side.
4. Implementar **client-side prediction** para movimiento y **lag compensation** para hit detection (rewind del servidor a la posición que veía el cliente cuando disparó).
5. Lobby con `ENetMultiplayerPeer` o `WebSocketMultiplayerPeer` para web.

---

## 11. Roadmap por fases

**Fase 0 — Setup.** ✅ COMPLETADA
Estructura de carpetas, autoloads, convenciones, README.

**Fase 1 — MVP single-player jugable.** ✅ COMPLETADA
Player capibara con movimiento procedural + rifle + 3 enemigos con AI + HUD completo + mapa de entrenamiento + audio + VFX.

**Fase 2 — Loop de juego.** ✅ COMPLETADA
Sistema de oleadas (4 waves con tipos mezclados), pickups (health/ammo) que dropean enemigos, weapon swap (rifle/pistola), main menu, pause menu con opciones, settings persistidas, game over + retry, kill streak con multiplicador.

**Fase 3 — Contenido y pulido.** 🟡 EN PROGRESO
Hecho: 3 tipos de enemigo (Grunt/Heavy/Sniper), assets PBR + stylized, toon shading look Fortnite, decals + sparks + damage numbers, animación de muerte del player.
Pendiente: música, modo endless, achievements, boss enemy, más armas (escopeta, granada), accesibilidad (subtítulos, daltonismo, escalado UI), localización (`tr()` wrapping), tests gdUnit4, build presets.

**Fase 4 — Multiplayer.** ⏳ PENDIENTE
NetworkManager autoload, MultiplayerSynchronizer en Player, RPC para take_damage/equip_weapon, lobby ENet, client-side prediction, lag compensation. Empezar con 2-4 jugadores cooperativo.

**Fase 5 — Live.** ⏳ PENDIENTE
Telemetría, analytics, updates, modding API.

---

## 12. Glosario

- **Autoload (Singleton):** nodo cargado al arrancar Godot, accesible globalmente por su nombre.
- **Component:** nodo con responsabilidad única que se *compone* en una entidad (prefiere esto sobre herencia).
- **EventBus:** singleton solo con *signals*; el "tablón de anuncios" del juego.
- **Hitscan:** disparo instantáneo por raycast (vs. *projectile*, que viaja con física).
- **Hitbox / Hurtbox:** Area3D que recibe daño / inflige daño melee.
- **Resource (`.tres`):** archivo de datos serializado que extiende `Resource`. Es *data*, no escena.
- **Server-authoritative:** el servidor es la única fuente de verdad sobre el estado del juego; el cliente predice y corrige.
- **Tick:** un paso de simulación de física/lógica (en `_physics_process`).
- **Lag compensation:** técnica server-side para validar hits según lo que el cliente *veía* en el momento del disparo, no en el momento que llega al servidor.

---

## Próximos pasos sugeridos (backlog priorizado)

Cuando retomes el desarrollo, este es el orden recomendado. Cada bullet
es ~1 iteración independiente — puedes saltar de uno a otro sin orden
estricto, pero estos están priorizados por **impacto / esfuerzo**.

### 🥇 Alta prioridad (lo que más mueve la aguja)

1. **Modo endless** — después de Wave 4, generar oleadas procedurales con dificultad escalada (cada N waves +20% HP, +10% velocidad). Nuevo botón "ENDLESS" en MainMenu. Tracking de "best wave reached" en Settings.
2. **Boss enemy en Wave 4** — entity especial con 600 HP, ataques especiales (charge attack, área de explosión). Reusa Enemy.gd con override de comportamiento o crea `BossAI.gd`.
3. **Más armas**: escopeta (multi-pellet hitscan, 8 pellets con spread alto, 6 mag), granada (proyectil con timer + radio de daño), launcher. Slot 3 keybind.
4. **Música + ambient** — bajar de Pixabay Music o Sonniss un track de combate loopeable. Crear `MusicManager` autoload con crossfade entre menú/combate/victoria.
5. **Achievements / medallas** — primer kill, kill streak x4, headshot, sobrevivir oleada sin daño. Toast notification en HUD esquina.

### 🥈 Polish y UX

6. **Rebinding de keys** en options menu. Iterar sobre `InputMap.get_actions()` y mostrar listener para cada acción.
7. **Tutorial / onboarding** — primera vez en TrainingMap, mostrar overlay con pista de controles. `Settings.first_run = false` después.
8. **Accesibilidad**: subtítulos para disparos enemigos cerca, modo daltonismo (paleta alternativa), escalado de UI (slider en options).
9. **Death animation del Enemy mejorada** — actualmente solo cae hacia adelante. Variar: caer hacia atrás, de lado, según dirección del último impacto.
10. **AI peek-and-shoot desde cobertura** — detectar StaticBody3D cercanos como cover, asomar/esconder en ATTACK state. Más complejo que strafe.

### 🥉 Calidad técnica

11. **Tests gdUnit4** — smoke tests para `HealthComponent.take_damage`, `WaveSystem._spawn_one`, `WeaponComponent.try_fire`. Carpeta `tests/unit/`.
12. **Localización** — wrap todos los strings en `tr()`, exportar a `.po`. Actualmente todo en español hardcoded.
13. **Pool de decals/audio** — máximo N decals/audio simultáneos. FIFO queue en `WeaponVFX` y `AudioManager`. Evita pile-up en full-auto largo.
14. **Build presets** — `Project > Export > Add Preset` para Windows/Linux/Web. Verifica que los assets se incluyen y no hay paths hardcoded.
15. **Telemetría** — eventos a un endpoint (kills, deaths, waves reached) para balance. `TelemetryManager` autoload con buffer + flush periódico.

### 🌐 Fase 4 — Multiplayer (cuando el SP esté sólido)

16. **NetworkManager** autoload con host/join/disconnect.
17. **MultiplayerSynchronizer** en Player para position/rotation/health.
18. Convertir `take_damage`, `equip_weapon`, `pick_up_item` a `@rpc`.
19. Client-side prediction para movimiento.
20. Lag compensation para hit detection (rewind del servidor).
21. Lobby con `ENetMultiplayerPeer`.

### Convenciones para continuar

- **Cada feature nueva**: crea task en TaskCreate (si usas el agente), implementa, marca completed.
- **Cada sistema nuevo** va en `scripts/systems/<nombre>/`. NO importa otros sistemas — usa `EventBus`.
- **Cada Resource nuevo** (datos): `class_name FooData extends Resource`, archivo en `resources/<categoría>/foo.tres`.
- **Cada signal nuevo de eventos cross-cutting**: añadirlo en `EventBus.gd`, no como signal local.
- **Cada asset bajado**: actualizar `assets/CREDITS.md` con licencia + autor + URL. Para fuentes nuevas, ver `docs/ASSET_SOURCES.md`.

### Qué NO toques sin pensar

- `class_name Player` y `class_name Enemy` — todo lo demás depende de estos.
- El orden de autoloads en `project.godot` — `EventBus` primero, `Settings` antes de cualquiera que escuche su signal.
- `MovementComponent.read_input` — el flag que diferencia Player (input humano) de Enemy (AI). Si lo cambias, ambos se rompen.
- La estructura de `Visuals/Head + ArmL + ArmR + LegL + LegR` en Player.tscn — `HumanoidAnimator` la usa por NodePath. Si renombras, anima nada.

---

## Documentos relacionados

- [`assets/CREDITS.md`](assets/CREDITS.md) — créditos de todos los assets de terceros (CC0 actualmente).
- [`docs/ASSET_SOURCES.md`](docs/ASSET_SOURCES.md) — guía curada de sitios para bajar más assets gratis (Poly Haven, Kenney, Quaternius, Mixamo, etc.) + sección dedicada a "look Fortnite".

---

## Changelog resumido

- **v0.1** — Scaffolding, arquitectura, autoloads vacíos.
- **v0.2** — Player humanoid + WASD + rifle hitscan + 1 enemigo dummy + HUD básico.
- **v0.3** — Animación procedural humanoid (caminar, brazos sostienen rifle), zoom, recoil, shake.
- **v0.4** — Bot enemigo con AI state machine + LOS, training map completo (galería + cobertura + parkour + maze + túnel).
- **v0.5** — VFX (decals + sparks + damage numbers + tracer + muzzle), audio (procedural → real OGG), HUD completo.
- **v0.6** — Sistema de oleadas, pickups, kill streak, weapon swap, pause menu, settings persistidas.
- **v0.7** — 3 tipos de enemigo, animación de muerte, hit marker, AI strafe, NavigationAgent3D pathfinding.
- **v0.8** — Player → capibara, assets PBR Poly Haven, toon shading + colores saturados (look stylized).
- **v0.9** — Main menu, mapa con flat colors saturados (look Fortnite genuino), README actualizado para retomar.
