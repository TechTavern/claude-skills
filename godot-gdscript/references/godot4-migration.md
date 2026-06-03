# Godot 3 → 4 Migration Reference

Consult this when you're unsure whether a class, method, or pattern is Godot 3 or 4. If you find yourself writing anything from the left column, stop and use the right column instead.

## Annotation Changes

| Godot 3 | Godot 4 |
|---|---|
| `onready var x = $Node` | `@onready var x: Type = $Node` |
| `export(int) var x` | `@export var x: int` |
| `export(int, 0, 100) var x` | `@export_range(0, 100) var x: int` |
| `export(String, "A", "B") var x` | `@export_enum("A", "B") var x: String` |
| `export(String, MULTILINE) var x` | `@export_multiline var x: String` |
| `export(String, FILE) var x` | `@export_file var x: String` |
| `export(String, DIR) var x` | `@export_dir var x: String` |
| `export(Color, RGB) var x` | `@export_color_no_alpha var x: Color` |
| `tool` | `@tool` |

## Export Organization (New in 4.x)

```gdscript
@export_category("Movement")
@export var speed: float = 200.0
@export var acceleration: float = 50.0

@export_group("Advanced")
@export var friction: float = 0.1

@export_subgroup("Debug")
@export var show_velocity: bool = false
```

## Signal Syntax

| Godot 3 | Godot 4 |
|---|---|
| `signal sig(a, b)` | `signal sig(a: int, b: float)` |
| `emit_signal("sig", a, b)` | `sig.emit(a, b)` |
| `connect("sig", target, "method")` | `sig.connect(target.method)` |
| `connect("sig", target, "method", [arg])` | `sig.connect(target.method.bind(arg))` |
| `disconnect("sig", target, "method")` | `sig.disconnect(target.method)` |
| `is_connected("sig", target, "method")` | `sig.is_connected(target.method)` |
| `yield(object, "signal")` | `await object.signal` |
| `yield(get_tree(), "idle_frame")` | `await get_tree().process_frame` |
| `yield(get_tree().create_timer(1), "timeout")` | `await get_tree().create_timer(1.0).timeout` |

## Class Renames

### Nodes

| Godot 3 | Godot 4 |
|---|---|
| `Spatial` | `Node3D` |
| `KinematicBody` | `CharacterBody3D` |
| `KinematicBody2D` | `CharacterBody2D` |
| `RigidBody` | `RigidBody3D` |
| `RigidBody2D` | `RigidBody2D` (unchanged) |
| `StaticBody` | `StaticBody3D` |
| `Area` | `Area3D` |
| `Sprite` | `Sprite2D` |
| `AnimatedSprite` | `AnimatedSprite2D` |
| `Position2D` | `Marker2D` |
| `Position3D` | `Marker3D` |
| `Camera` | `Camera3D` |
| `Listener` | `AudioListener3D` |
| `Light` | `Light3D` |
| `DirectionalLight` | `DirectionalLight3D` |
| `OmniLight` | `OmniLight3D` |
| `SpotLight` | `SpotLight3D` |
| `MeshInstance` | `MeshInstance3D` |
| `MultiMeshInstance` | `MultiMeshInstance3D` |
| `CollisionShape` | `CollisionShape3D` |
| `CollisionPolygon` | `CollisionPolygon3D` |
| `RayCast` | `RayCast3D` |
| `YSort` | Node2D with `y_sort_enabled = true` |
| `VisibilityNotifier` | `VisibleOnScreenNotifier3D` |
| `VisibilityEnabler` | `VisibleOnScreenEnabler3D` |
| `Navigation` | Removed (use `NavigationServer3D`) |
| `Navigation2D` | Removed (use `NavigationServer2D`) |

### Servers and Singletons

| Godot 3 | Godot 4 |
|---|---|
| `VisualServer` | `RenderingServer` |
| `Navigation2DServer` | `NavigationServer2D` |
| `NavigationServer` | `NavigationServer3D` |

### Data Types

| Godot 3 | Godot 4 |
|---|---|
| `PoolByteArray` | `PackedByteArray` |
| `PoolIntArray` | `PackedInt32Array` |
| `PoolRealArray` | `PackedFloat64Array` |
| `PoolStringArray` | `PackedStringArray` |
| `PoolVector2Array` | `PackedVector2Array` |
| `PoolVector3Array` | `PackedVector3Array` |
| `PoolColorArray` | `PackedColorArray` |
| `Transform` | `Transform3D` |
| `Quat` | `Quaternion` |
| `Basis` (unchanged) | `Basis` |

## Method Renames

| Godot 3 | Godot 4 |
|---|---|
| `instance()` | `instantiate()` |
| `update()` | `queue_redraw()` |
| `get_tree().change_scene("path")` | `get_tree().change_scene_to_file("path")` |
| `str2var()` | `str_to_var()` |
| `var2str()` | `var_to_str()` |
| `stepify()` | `snapped()` |
| `range_lerp()` | `remap()` |
| `rand_range()` | `randf_range()` |
| `decimals()` | Removed |
| `get_world()` | `get_world_3d()` |
| `get_world_2d()` | `get_world_2d()` (unchanged) |

## Tween API (Completely Rewritten)

```gdscript
# Godot 3 — Tween was a node in the scene tree
var tween = $Tween  # or Tween.new()
tween.interpolate_property(sprite, "modulate:a", 1.0, 0.0, 0.5,
    Tween.TRANS_LINEAR, Tween.EASE_IN)
tween.start()

# Godot 4 — Tweens are created on-demand, auto-start, self-free
var tween := create_tween()
tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
# Starts automatically. One-shot by default (frees itself when done).

# Chaining
var tween := create_tween()
tween.tween_property(node, "position", target_pos, 0.5)
tween.tween_callback(on_arrived)

# Parallel tweens
var tween := create_tween().set_parallel(true)
tween.tween_property(node, "position", target_pos, 0.5)
tween.tween_property(node, "modulate:a", 0.0, 0.5)

# Transitions and easing
tween.tween_property(node, "position", target_pos, 0.5)\
    .set_trans(Tween.TRANS_CUBIC)\
    .set_ease(Tween.EASE_OUT)
```

## CharacterBody Movement (Completely Changed)

```gdscript
# Godot 3
velocity = move_and_slide(velocity, Vector3.UP)

# Godot 4 — velocity is a built-in property
velocity += gravity * delta
move_and_slide()  # No arguments. Uses self.velocity directly.
# After move_and_slide(), velocity is updated with collisions applied.
```

## Pause System

| Godot 3 | Godot 4 |
|---|---|
| `pause_mode = PAUSE_MODE_PROCESS` | `process_mode = PROCESS_MODE_ALWAYS` |
| `pause_mode = PAUSE_MODE_STOP` | `process_mode = PROCESS_MODE_PAUSABLE` |
| `pause_mode = PAUSE_MODE_INHERIT` | `process_mode = PROCESS_MODE_INHERIT` |
| N/A | `process_mode = PROCESS_MODE_WHEN_PAUSED` |
| N/A | `process_mode = PROCESS_MODE_DISABLED` |

## Input Handling

```gdscript
# Preferred for one-shot actions (respects UI input consumption)
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("fire"):
        fire()

# Also acceptable (runs before UI)
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("pause"):
        toggle_pause()

# For continuous state checking (held keys), use in _process/_physics_process:
func _physics_process(_delta: float) -> void:
    if Input.is_action_pressed("move_forward"):
        velocity += transform.basis.z * speed
```

## Callable and Deferred Calls

```gdscript
# Godot 3
call_deferred("method_name", arg1)
set_deferred("property", value)

# Godot 4 — Callable-based (preferred)
method_name.call_deferred(arg1)
set_deferred("property", value)  # This one is unchanged
```
