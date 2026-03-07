extends CharacterBody2D

# Movement
@export var speed: float = 80.0
@export var attack_range: float = 30.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0

# Combat
@export var health: int = 3

# References
var player: CharacterBody2D = null
var can_attack: bool = true
var is_dead: bool = false
var is_attacking: bool = false   # true only during the attack animation
var pending_death: bool = false  # hurt is playing; death is queued


enum State { IDLE, RUN, ATTACK, HIT, DEAD }
var current_state: State = State.IDLE

# Node references
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var wind_sfx: AudioStreamPlayer2D = $WindSFX
@onready var impact_sfx: AudioStreamPlayer2D = $ImpactSFX
@onready var death_sfx: AudioStreamPlayer2D = $DeathSFX
@onready var attack_timer: Timer = $AttackTimer
@onready var body_col: CollisionShape2D = $CollisionShape2D

const BLOOD_PARTICLES = preload("res://Scenes/blood_particles.tscn")

# Shader material for hit flash
var hit_flash_material: ShaderMaterial

func _ready():
	player = get_tree().get_first_node_in_group("player")
	animated_sprite.animation_finished.connect(_on_animation_finished)
	attack_timer.timeout.connect(_on_attack_timer_timeout)

	if animated_sprite.material is ShaderMaterial:
		hit_flash_material = animated_sprite.material

	if SettingsManager.sound_enabled:
		wind_sfx.play()
	change_state(State.IDLE)

func change_state(new_state: State):
	if current_state == new_state:
		return
	exit_state(current_state)
	current_state = new_state
	enter_state(new_state)

func exit_state(state: State):
	match state:
		State.ATTACK:
			is_attacking = false

func enter_state(state: State):
	match state:
		State.IDLE:
			animated_sprite.play("idle")

		State.RUN:
			animated_sprite.play("run")

		State.ATTACK:
			is_attacking = true
			can_attack = false
			attack_timer.start()
			animated_sprite.play("attack")

		State.HIT:
			animated_sprite.play("hit")

		State.DEAD:
			is_attacking = false
			animated_sprite.play("death")
			wind_sfx.stop()
			# Remove from own layer so player can pass through,
			# but keep ground in mask so gravity still lands them
			collision_layer = 0
			collision_mask = 1

func _on_animation_finished():
	match current_state:
		State.ATTACK:
			if player and global_position.distance_to(player.global_position) <= attack_range:
				change_state(State.IDLE)
			else:
				change_state(State.RUN)

		State.HIT:
			if pending_death:
				pending_death = false
				is_dead = true
				change_state(State.DEAD)
			elif player and global_position.distance_to(player.global_position) <= attack_range:
				change_state(State.IDLE)
			else:
				change_state(State.RUN)

		State.DEAD:
			queue_free()

func _physics_process(delta):
	if current_state == State.DEAD:
		if not is_on_floor():
			velocity += get_gravity() * delta
			move_and_slide()
		return

	if is_dead or current_state == State.HIT or current_state == State.ATTACK:
		return

	if player == null:
		change_state(State.IDLE)
		return

	var direction = (player.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(player.global_position)

	if distance_to_player <= attack_range:
		velocity = Vector2.ZERO
		if can_attack:
			change_state(State.ATTACK)
		elif current_state != State.IDLE:
			change_state(State.IDLE)
	else:
		velocity = direction * speed
		move_and_slide()
		if current_state != State.RUN:
			change_state(State.RUN)

	update_facing_direction(direction)

func update_facing_direction(direction: Vector2):
	if direction.x != 0:
		animated_sprite.flip_h = direction.x < 0

func take_damage(damage: int):
	if is_dead or pending_death:
		return

	health -= damage
	if health <= 0:
		pending_death = true

	if SettingsManager.sound_enabled:
		if not pending_death:
			impact_sfx.play()
		else:
			death_sfx.play()
	if SettingsManager.hit_flash_enabled and hit_flash_material:
		hit_flash_material.set_shader_parameter("hit_effect", 0.5)
		await get_tree().create_timer(0.1).timeout
		hit_flash_material.set_shader_parameter("hit_effect", 0.0)
	if SettingsManager.blood_enabled:
		var dir := (global_position - player.global_position).normalized() if player else Vector2.RIGHT
		_spawn_blood(dir)
	
	change_state(State.HIT)

func _on_attack_timer_timeout():
	can_attack = true

func _spawn_blood(direction: Vector2) -> void:
	var blood = BLOOD_PARTICLES.instantiate()
	blood.global_position = global_position
	blood.rotation = direction.angle()
	get_parent().add_child(blood)
