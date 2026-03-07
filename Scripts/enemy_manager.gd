extends Node2D

@export var enemy_types: Array[PackedScene] = []

# How often a new enemy spawns (seconds). Decreases over time.
@export var initial_spawn_interval: float = 3.0
@export var min_spawn_interval: float = 0.5
# How much the interval shrinks each time an enemy spawns.
@export var interval_decrease: float = 0.05

# Spawn band follows the player; enemies won't spawn closer than this.
@export var spawn_half_width: float = 300.0
@export var spawn_y: float = 86.0
@export var min_distance_from_player: float = 100.0

var player: Node2D = null
var spawn_timer: Timer
var _current_interval: float

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

	spawn_timer = Timer.new()
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

	_current_interval = initial_spawn_interval
	spawn_timer.start(_current_interval)

func _on_spawn_timer_timeout() -> void:
	_spawn_enemy()
	_current_interval = maxf(_current_interval - interval_decrease, min_spawn_interval)
	spawn_timer.start(_current_interval)

func _spawn_enemy() -> void:
	if enemy_types.is_empty():
		return

	var spawn_pos := _get_spawn_position()
	if spawn_pos == Vector2.ZERO:
		return

	var enemy = enemy_types[randi() % enemy_types.size()].instantiate()
	enemy.position = spawn_pos
	enemy.tree_exited.connect(_on_enemy_removed.bind(enemy))
	add_child(enemy)

func _get_spawn_position() -> Vector2:
	var center_x := player.global_position.x if player else 0.0
	for _i in 30:
		var x := randf_range(center_x - spawn_half_width, center_x + spawn_half_width)
		var candidate := Vector2(x, spawn_y)
		if not player or candidate.distance_to(player.global_position) >= min_distance_from_player:
			return candidate
	return Vector2.ZERO

func _on_enemy_removed(_enemy) -> void:
	pass

func stop_spawning() -> void:
	spawn_timer.stop()

func clear_all_enemies() -> void:
	for child in get_children():
		if child != spawn_timer:
			child.queue_free()
