# worldFarm — Shooter en Godot 4.6

Proyecto de un juego **shooter** desarrollado en **Godot 4.6** (3D, Jolt Physics, Forward+).
Comienza como **single-player** y está pensado para escalar a **multiplayer** (autoritativo de servidor) sin reescribir la base.

> Este README es la guía maestra del proyecto: arquitectura, sistemas, convenciones y workflow. Lectura recomendada en orden.

---

## Tabla de contenidos

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

| Sistema | Carpeta | Responsabilidad | Componentes que expone |
|---------|---------|-----------------|------------------------|
| **Input** | `systems/input/` | Lectura de teclado/ratón/gamepad, rebinding, dead zones. | `InputBuffer` (para combos), action map. |
| **Movement** | `components/MovementComponent.gd` | Walk, run, jump, crouch, sliding. Físico con `CharacterBody3D` + Jolt. | Signals: `jumped`, `landed`, `started_running`. |
| **Camera** | `systems/camera/` | 1ª persona / 3ª persona, head bob, FOV dinámico al correr, recoil-camera-kick. | `CameraRig.tscn`. |
| **Combat / Shooting** | `systems/combat/` | Hitscan y projectile, spread, recoil, daño, headshots. | `WeaponComponent`, `HitboxComponent`, `DamageInfo`. |
| **Health & Damage** | `components/HealthComponent.gd` | HP, armor, daño, curación, muerte, invulnerabilidad temporal. | Signals: `damaged`, `healed`, `died`. |
| **Inventory** | `systems/inventory/` | Slots, stacks, hotbar, equipar, drop. | `InventoryComponent`, `ItemData` resource. |
| **Weapon** | `systems/combat/weapon/` | Equipar, recargar, ammo en mag/reserva, switch entre armas. | `WeaponComponent`, `WeaponData` resource. |
| **Pickup / Loot** | `systems/spawning/` | Items en el mundo, drop al morir enemigos, magnet pickup. | `Pickup.tscn`, `LootTable` resource. |
| **AI / Enemy** | `systems/ai/` | State Machine (Idle → Patrol → Chase → Attack → Dead), percepción (vista, audio). | `AIController`, `PerceptionComponent`. |
| **Spawning** | `systems/spawning/` | Spawn de enemigos por oleadas / triggers / timers. | `Spawner.tscn`, `WaveData` resource. |
| **UI / HUD** | `systems/ui/` | Vida, ammo, hotbar, crosshair, daño direccional, menús. | `HUD.tscn`, `Menu.tscn`. |
| **Audio** | `systems/audio/` | Pool de `AudioStreamPlayer3D`, music bus, sfx con pitch/volume aleatorio. | `AudioManager` autoload. |
| **VFX** | `systems/vfx/` | Muzzle flash, decals de impacto, sangre, explosiones. Pool de partículas. | `VFXManager`. |
| **Save / Load** | `systems/save/` | Serialización de estado relevante (progresión, settings, no posiciones). | `SaveSystem` autoload. |
| **GameState / Round** | `autoload/GameState.gd` | Score, ronda, modo, victoria/derrota, pausa. | Signals: `round_started`, `round_ended`. |
| **Settings** | `autoload/Settings.gd` | Volumen, sensibilidad, gamma, keybindings. | Persiste en `user://settings.cfg`. |

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

**Fase 0 — Setup (este README + scaffolding).** ✅
Estructura de carpetas, autoloads vacíos, convenciones acordadas.

**Fase 1 — MVP single-player jugable.**
Player con movimiento + 1 arma + 1 enemigo dummy + HUD básico + 1 mapa de prueba. Sistemas: Input, Movement, Camera, Combat, Health, Weapon, HUD, Audio mínimo.

**Fase 2 — Loop de juego.**
Inventory, Pickup, Spawning por oleadas, AI con state machine, varias armas, Save de progreso, menús (main menu, pausa, opciones).

**Fase 3 — Contenido y pulido.**
Más enemigos, más armas, VFX, audio completo, balanceo, accesibilidad básica.

**Fase 4 — Multiplayer.**
NetworkManager, sync, lobby, prediction, lag compensation. 2-4 jugadores cooperativo primero, PvP después.

**Fase 5 — Live.**
Telemetría, analytics, posibles updates, modding.

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

## Próximos pasos en este repo

1. Crear los autoloads vacíos (`EventBus`, `GameState`, `RNG`, `Settings`) y registrarlos en `Project Settings > Autoload`.
2. Implementar `HealthComponent` + un test de daño en `tests/integration/`.
3. Implementar `MovementComponent` + Player mínimo en una escena sandbox.
4. Implementar `WeaponComponent` con un `WeaponData` de pistola hitscan.
5. Conectar todo con el EventBus y validar el flujo del §9.

> Cuando un sistema esté listo, añadir aquí una nota corta y un link a su README específico en `docs/`.
