extends Node2D

# Enemy types
@export var enemy_types: Array[PackedScene] = []
@export var elite_enemy_types: Array[PackedScene] = []

# Wave settings
@export var base_spawn_interval: float = 2.0
@export var base_enemies_per_wave: int = 3
@export var wave_increase_rate: float = 0.5  # How much harder each wave gets

# Spawn area
@export var spawn_area: Rect2 = Rect2(100, 86, 600, 20)  # Spawn HIGHER (Y=300)
@export var min_distance_from_player: float = 100.0  # Don't spawn too close
var time: float = 0

@export var ground_y: float = 450

# Current wave state
var current_wave: int = 0
var enemies_to_spawn: int = 0
var enemies_spawned_in_wave: int = 0
var active_enemies: Array = []

# References
var player: Node2D = null
var spawn_timer: Timer
var wave_timer: Timer

func _ready():
	player = get_tree().get_first_node_in_group("player")
	
	# Create spawn timer
	spawn_timer = Timer.new()
	spawn_timer.timeout.connect(_spawn_enemy)
	add_child(spawn_timer)
	
	# Create wave timer (for delays between waves)
	wave_timer = Timer.new()
	wave_timer.timeout.connect(_start_next_wave)
	wave_timer.one_shot = true
	add_child(wave_timer)
	
	# Start first wave
	start_wave(1)

func _process(delta):
	time += delta
	
	# Make spawn area pulse slightly
	spawn_area.size.x = 600 + sin(time * 2) * 50
	
	# Or make it follow the player
	if player:
		spawn_area.position.x = player.global_position.x - 300

func start_wave(wave_number: int):
	current_wave = wave_number
	enemies_to_spawn = base_enemies_per_wave + int(wave_number * wave_increase_rate)
	enemies_spawned_in_wave = 0
	
	print("Starting Wave ", current_wave, " - Spawning ", enemies_to_spawn, " enemies")
	
	# Start spawning
	spawn_timer.wait_time = base_spawn_interval / (1.0 + (wave_number * 0.1))  # Faster spawns in later waves
	spawn_timer.start()

func _spawn_enemy():
	if enemies_spawned_in_wave >= enemies_to_spawn:
		# Check if wave is complete
		if active_enemies.size() == 0:
			_wave_complete()
		return
	
	# Choose enemy type
	var enemy_scene: PackedScene
	if current_wave >= 3 and randf() < 0.3:  # 30% chance for elite in later waves
		enemy_scene = elite_enemy_types[randi() % elite_enemy_types.size()]
	else:
		enemy_scene = enemy_types[randi() % enemy_types.size()]
	
	# Spawn enemy
	var enemy = enemy_scene.instantiate()
	
	# Find safe spawn position
	var spawn_pos = _get_safe_spawn_position()
	if spawn_pos:
		enemy.position = spawn_pos
		
		# Connect to enemy death
		if enemy.has_signal("died"):  # If you add a custom signal
			enemy.died.connect(_on_enemy_died.bind(enemy))
		else:
			# Fallback to tree_exited
			enemy.tree_exited.connect(_on_enemy_died.bind(enemy))
		
		add_child(enemy)
		active_enemies.append(enemy)
		enemies_spawned_in_wave += 1
		
		print("Spawned enemy ", enemies_spawned_in_wave, "/", enemies_to_spawn)
	else:
		print("Couldn't find safe spawn position")

func _get_safe_spawn_position() -> Vector2:
	var attempts = 0
	var max_attempts = 30
	
	while attempts < max_attempts:
		var random_x = randf_range(spawn_area.position.x, spawn_area.position.x + spawn_area.size.x)
		var random_y = randf_range(spawn_area.position.y, spawn_area.position.y + spawn_area.size.y)
		var test_pos = Vector2(random_x, random_y)
		
		# Check distance from player
		if player:
			if test_pos.distance_to(player.global_position) < min_distance_from_player:
				attempts += 1
				continue
		
		# Check if position is valid (not inside walls, etc.)
		# You could add more checks here
		
		return test_pos
	
	return Vector2.ZERO  # Return zero if no safe spot found

func _on_enemy_died(enemy):
	active_enemies.erase(enemy)
	print("Enemy died. Active enemies: ", active_enemies.size())
	
	# Check if wave is complete
	if enemies_spawned_in_wave >= enemies_to_spawn and active_enemies.size() == 0:
		_wave_complete()

func _wave_complete():
	print("Wave ", current_wave, " complete!")
	
	# Wait before next wave
	wave_timer.wait_time = 3.0
	wave_timer.start()

func _start_next_wave():
	start_wave(current_wave + 1)

# Manual control functions
func spawn_single_enemy():
	enemies_to_spawn += 1
	_spawn_enemy()

func clear_all_enemies():
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()

func stop_spawning():
	spawn_timer.stop()
