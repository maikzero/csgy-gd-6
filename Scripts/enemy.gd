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
@onready var blood_particles: GPUParticles2D = $BloodParticles
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var attack_timer: Timer = $AttackTimer
@onready var body_col: CollisionShape2D = $CollisionShape2D

# Shader material for hit flash
var hit_flash_material: ShaderMaterial

func _ready():
	player = get_tree().get_first_node_in_group("player")
	animated_sprite.animation_finished.connect(_on_animation_finished)
	attack_timer.timeout.connect(_on_attack_timer_timeout)

	if animated_sprite.material is ShaderMaterial:
		hit_flash_material = animated_sprite.material

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
			if SettingsManager.blood_enabled:
				blood_particles.emitting = true
			if SettingsManager.sound_enabled:
				audio_player.play()

		State.DEAD:
			is_attacking = false
			animated_sprite.play("death")
			body_col.disabled = true
			set_physics_process(false)

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

func _physics_process(_delta):
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

	if SettingsManager.sound_enabled:
		audio_player.play()
	if SettingsManager.hit_flash_enabled and hit_flash_material:
		hit_flash_material.set_shader_parameter("hit_effect", 1.0)
		await get_tree().create_timer(0.1).timeout
		hit_flash_material.set_shader_parameter("hit_effect", 0.0)
	if SettingsManager.blood_enabled:
		blood_particles.emitting = true

	if health <= 0:
		pending_death = true
	
	change_state(State.HIT)

func _on_attack_timer_timeout():
	can_attack = true
