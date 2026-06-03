---
name: godot-gdscript
description: "Godot 4.x GDScript development guide — enforces modern Godot 4 syntax, static typing, style conventions, and scene patterns while preventing Godot 3.x anti-patterns from training data. Use this skill whenever writing, modifying, reviewing, or debugging GDScript code (.gd files), creating or editing Godot scenes (.tscn), or working on any Godot 4 project. Also use when the user mentions GDScript, Godot nodes, signals, scenes, or any Godot game development task — even if they don't explicitly ask for 'best practices.' This skill is essential because AI training data heavily mixes Godot 3 and 4 syntax, leading to subtle bugs that compile but behave incorrectly."
---

# Godot 4.x GDScript Development

This is a **rigid** skill. Follow it exactly when writing GDScript or working with Godot scenes. The rules here prevent real bugs — especially Godot 3.x syntax that silently compiles in some contexts but produces wrong behavior.

## Pre-Flight Check

Before writing or modifying any GDScript, verify these:

1. **Target version**: Confirm the project's Godot version from `project.godot` (`config/features`). All rules below assume Godot 4.x.
2. **Existing patterns**: Read at least one existing `.gd` file in the same directory to match local conventions (naming, signal style, typing approach).
3. **API uncertainty**: If you're about to use a method or class you haven't seen in this project's code, verify it exists in Godot 4 before writing it. Use `WebFetch` against `https://docs.godotengine.org/en/stable/classes/` or check the project's Godot version docs. Training data mixes Godot 3 and 4 heavily — don't guess.

## Core Rules

### 1. Godot 4 Syntax Only

This is the highest-priority rule. Godot 3 syntax is the single most common source of AI-generated bugs in GDScript.

**Annotations use `@` prefix:**
```gdscript
@onready var sprite: Sprite2D = $Sprite2D
@export var speed: float = 200.0
@export_range(0, 100) var health: int = 100
@tool
```
Never write bare `onready`, `export`, or `tool` without `@`.

**Signals — modern syntax only:**
```gdscript
# Declaring
signal health_changed(old_value: int, new_value: int)

# Emitting
health_changed.emit(old_hp, new_hp)

# Connecting
health_changed.connect(_on_health_changed)
health_changed.connect(_on_health_changed.bind(extra_arg))

# One-shot
timer.timeout.connect(_on_timeout, CONNECT_ONE_SHOT)
```
Never use `emit_signal("name")`, `connect("signal", target, "method")`, or `yield()`.

**Await replaces yield:**
```gdscript
await get_tree().create_timer(1.0).timeout
await animation_player.animation_finished
```

**Key class renames** (Godot 3 names do not exist in 4):

| Godot 3 | Godot 4 |
|---|---|
| `Spatial` | `Node3D` |
| `KinematicBody` / `KinematicBody2D` | `CharacterBody3D` / `CharacterBody2D` |
| `Sprite` | `Sprite2D` |
| `Position2D` / `Position3D` | `Marker2D` / `Marker3D` |
| `Area` | `Area3D` |
| `RigidBody` | `RigidBody3D` |

**Key method renames:**

| Godot 3 | Godot 4 |
|---|---|
| `instance()` | `instantiate()` |
| `update()` | `queue_redraw()` |
| `change_scene()` | `change_scene_to_file()` |
| `str2var()` | `str_to_var()` |
| `var2str()` | `var_to_str()` |
| `stepify()` | `snapped()` |
| `range_lerp()` | `remap()` |
| `rand_range()` | `randf_range()` |
| `PoolByteArray` | `PackedByteArray` |

**Other critical changes:**
- `process_mode = Node.PROCESS_MODE_ALWAYS` (not `pause_mode`)
- Tweens: `var tween = create_tween()` then `tween.tween_property(...)` — not a Tween node, auto-starts, one-shot by default
- `move_and_slide()` takes no arguments in 4.x — set the `velocity` property first
- `get_world_3d()` not `get_world()`

For the complete migration table, read `references/godot4-migration.md`.

### 2. Static Typing — Always

Every variable, parameter, and return type must be typed. This catches bugs at parse time and enables GDScript compiler optimizations.

```gdscript
# Variables
var speed: float = 200.0
var enemies: Array[Enemy] = []
var lookup: Dictionary[String, int] = {}  # Godot 4.4+

# Functions — always type parameters and return
func take_damage(amount: int) -> void:
    health -= amount

func get_nearest_enemy() -> Enemy:
    return _cached_enemy

# Use := when the type is obvious from the right side
var timer := Timer.new()
var name := "Player"

# Explicit type when get_node() is involved
@onready var health_bar: ProgressBar = $UI/HealthBar
@onready var camera: Camera3D = %MainCamera
```

Mark functions that return nothing with `-> void`. This documents intent and catches accidental returns.

### 3. Code Organization

Follow this exact ordering within each `.gd` file:

```
@tool / @icon / @static_unload     (if applicable)
class_name
extends
## doc comments
signals
enums
constants
static variables
@export variables
regular variables
@onready variables
_static_init()
virtual methods (_init, _enter_tree, _ready, _process, _physics_process)
public methods
private methods (_prefixed)
inner classes
```

**Naming conventions:**

| Element | Convention | Example |
|---|---|---|
| Files | snake_case | `camera_rig.gd` |
| Classes | PascalCase | `class_name CameraRig` |
| Functions | snake_case | `func update_position()` |
| Variables | snake_case | `var move_speed` |
| Signals | snake_case, past tense | `signal target_locked` |
| Constants | CONSTANT_CASE | `const MAX_ZOOM` |
| Enums | PascalCase name, CONSTANT_CASE members | `enum State { IDLE, MOVING }` |
| Private | `_` prefix | `var _internal_timer` |

**Formatting:**
- Tabs for indentation (not spaces)
- Lines under 100 characters
- `and` / `or` / `not` (not `&&` / `||` / `!`)
- Double quotes for strings
- Trailing commas on multi-line arrays, dictionaries, enums
- Two blank lines between functions and classes

### 4. Node and Scene Patterns

**"Call down, signal up"** — the foundational Godot architecture rule:
- Parents call methods on children: `$Child.activate()`
- Children emit signals: `signal activated`; parents connect to them
- Children never reach into parents: no `get_parent().get_parent().do_thing()`
- Siblings communicate through a shared ancestor, not directly

**Node references:**
```gdscript
# Best: unique names (same scene, robust to restructuring)
@onready var label: Label = %StatusLabel

# Good: @export for cross-scene or inspector-configured refs
@export var target: Node3D

# Acceptable: short $ paths for direct children
@onready var sprite: Sprite2D = $Sprite2D

# Bad: deep relative paths (fragile)
# var label = get_node("../../UI/HUD/StatusLabel")  # DON'T
```

**Node lifecycle:**
- Use `@onready` for node refs — bare `$Node` at class level evaluates before the node exists
- Set properties BEFORE `add_child()` — `_ready()` fires on add, so late assignments miss it
- Always `queue_free()`, never `free()` — immediate free crashes if anything references the node this frame
- Nodes created with `.new()` must be added to tree or explicitly freed, or they leak

**When a node might not exist:**
```gdscript
var weapon := get_node_or_null("WeaponSlot/Current") as Weapon
if weapon:
    weapon.fire()
```

**Use `is_instance_valid()` for freed-node checks**, not bare `if target:` — a freed reference is not null, it's a dangling pointer that will crash.

### 5. Signals

- Type signal parameters: `signal damage_dealt(amount: float, source: Node3D)`
- Name signals in past tense: `door_opened`, `target_acquired`, `health_depleted`
- Use `CONNECT_ONE_SHOT` for signals you only need once
- Check `is_connected()` before connecting in loops or repeated code paths
- In lambdas that capture node references, guard with `is_instance_valid()`

### 6. Performance

- **Signals over polling**: If you're checking a condition every frame in `_process`, there's probably a signal or setter that can trigger the reaction instead
- **Disable idle processing**: `set_process(false)` in `_ready()` for nodes that don't need every-frame updates; enable when needed
- **Cache node refs**: Use `@onready` — never call `get_node()` or `$Path` inside `_process` or loops
- **StringName for hot paths**: Use `&"group_name"` for group names, input action names, and dictionary keys used in per-frame code
- **Preload vs load**: `preload()` for resources known at compile time; `load()` for runtime-determined resources; never `load()` inside `_process`
- **Physics signals**: Use `body_entered` / `body_exited` signals instead of calling `get_overlapping_bodies()` each frame
- **`_process` vs `_physics_process`**: Visual updates in `_process`, physics/movement in `_physics_process`

### 7. Architecture

- **Autoloads**: Single responsibility. Never reach into the scene tree from an autoload — communicate via signals or have scenes call the autoload
- **Composition**: Prefer child nodes with focused scripts over monolithic scripts. If a script exceeds ~300 lines, consider decomposing
- **State machines**: Use enums, not boolean soup (`is_running and not is_jumping and not is_dead`)
- **Type checking**: `if node is CharacterBody3D:` — not `if node.get_class() == "CharacterBody3D":`
- **Groups for collections**: `get_tree().get_nodes_in_group(&"enemies")` instead of maintaining manual arrays
- **World-space math**: Always `global_position`, never `position`, for distance/direction calculations between nodes with different parents
- **Resource loading**: Set properties before adding to tree; use `ResourceLoader.load_threaded_request()` for large resources to avoid frame stutter

## Post-Write Review

After writing GDScript, check each item:

- [ ] No Godot 3 syntax: no bare `onready`/`export`/`tool`, no `emit_signal()`, no `connect("sig", target, "method")`, no `yield()`, no `instance()`
- [ ] All variables, parameters, and return types are statically typed
- [ ] `-> void` on functions that return nothing
- [ ] Code follows the ordering convention (signals → enums → constants → exports → vars → @onready → virtuals → methods)
- [ ] Node refs use `@onready` or `@export`, not bare class-level `$`
- [ ] No deep relative paths like `../../`
- [ ] `queue_free()` not `free()`
- [ ] Signals are past-tense, typed parameters
- [ ] No `get_node()` or `$` inside `_process` / `_physics_process`
- [ ] Physics/movement logic in `_physics_process`, not `_process`
- [ ] Any API method I'm uncertain about has been verified against Godot 4 docs

## API Verification

When uncertain about any Godot API:

1. First check if the method/class is used elsewhere in this project
2. If not found, fetch the relevant class docs:
   `https://docs.godotengine.org/en/stable/classes/class_{classname}.html`
3. Verify: method name, parameter order, return type, and that it exists in Godot 4

Common traps where training data is unreliable:
- `AnimationPlayer` method signatures changed significantly in 4.x
- `TileMap` API was completely rewritten in 4.x
- `NavigationAgent3D` setup differs from Godot 3
- `PhysicsDirectSpaceState3D` query methods changed
- Shader language has subtle differences from 3.x
