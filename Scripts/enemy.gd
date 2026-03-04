extends CharacterBody2D

# Movement
@export var speed: float = 80.0
@export var attack_range: float = 50.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0

# Combat
@export var health: int = 3
@export var death_remove_delay: float = 1.0  # Time before removing after death

# References
var player: CharacterBody2D = null
var can_attack: bool = true
var is_dead: bool = false
var is_hurt: bool = false


enum State { IDLE, RUN, ATTACK, HURT, DEAD }
var current_state: State = State.IDLE

# Node references
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var blood_particles: GPUParticles2D = $BloodParticles
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var attack_timer: Timer = $AttackTimer
@onready var hurt_timer: Timer = $HurtTimer  # Add this as a child node

# Shader material for hit flash
var hit_flash_material: ShaderMaterial

func _ready():
	# Find player
	player = get_tree().get_first_node_in_group("player")
	print("Player found: ", player)  # DEBUG
	print("Player group members: ", get_tree().get_nodes_in_group("player"))  # DEBUG
	
		# DEBUG: Check if animations exist
	if animated_sprite.sprite_frames:
		print("Animations available: ", animated_sprite.sprite_frames.get_animation_names())
	else:
		print("ERROR: No sprite frames assigned!")
	
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# Try to play something
	change_state(State.IDLE)
	
	# Setup timers if they don't exist
	if not attack_timer:
		attack_timer = Timer.new()
		attack_timer.wait_time = attack_cooldown
		attack_timer.one_shot = true
		attack_timer.timeout.connect(_on_attack_timer_timeout)
		add_child(attack_timer)
	
	if not hurt_timer:
		hurt_timer = Timer.new()
		hurt_timer.wait_time = 0.3  # How long hurt animation plays
		hurt_timer.one_shot = true
		hurt_timer.timeout.connect(_on_hurt_timer_timeout)
		add_child(hurt_timer)
	
	# Setup hit flash material
	if animated_sprite.material is ShaderMaterial:
		hit_flash_material = animated_sprite.material
	
	# Start with idle animation
	play_animation("idle")

func change_state(new_state: State):
	# Don't change if already in that state
	if current_state == new_state:
		return
	
	# Exit current state
	exit_state(current_state)
	
	# Set new state
	current_state = new_state
	
	# Enter new state
	enter_state(new_state)
	
	
func exit_state(state: State):
	match state:
		State.ATTACK:
			# Any cleanup when leaving attack state
			pass
		State.HURT:
			# Any cleanup when leaving hurt state
			pass

func enter_state(state: State):
	match state:
		State.IDLE:
			animated_sprite.play("idle")
		
		State.RUN:
			animated_sprite.play("run")
		
		State.ATTACK:
			animated_sprite.play("attack")
			# Deal damage when attack starts
			if player and global_position.distance_to(player.global_position) <= attack_range:
				if player.has_method("take_damage"):
					player.take_damage(attack_damage)
		
		State.HURT:
			animated_sprite.play("hurt")
			
			# Your 4 toggles here
			if SettingsManager.blood_enabled:
				blood_particles.emitting = true
			if SettingsManager.sound_enabled:
				audio_player.play()
		
		State.DEAD:
			animated_sprite.play("death")
			# Disable collision so player can run through
			$CollisionShape2D.disabled = true
			# Stop processing
			set_physics_process(false)

func _on_animation_finished():
	match current_state:
		State.ATTACK:
			# After attack, go back to idle/run
			if player and global_position.distance_to(player.global_position) <= attack_range:
				change_state(State.IDLE)
			else:
				change_state(State.RUN)
		
		State.HURT:
			# After hurt, go back to idle/run
			if player and global_position.distance_to(player.global_position) <= attack_range:
				change_state(State.IDLE)
			else:
				change_state(State.RUN)
		
		State.DEAD:
			# Remove enemy after death animation
			queue_free()

func _physics_process(delta):
	# Don't do anything if dead or hurt
	if is_dead or is_hurt:
		return
	
	if player == null:
		play_animation("idle")
		return
	
	# Calculate distance and direction
	var direction = (player.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Check if in attack range
	if distance_to_player <= attack_range:
		# Stop moving
		velocity = Vector2.ZERO
		
		# Attack if cooldown is ready
		if can_attack:
			attack_player()
		else:
			# Wait while attacking
			if animated_sprite.animation != "attack":
				play_animation("idle")
	else:
		# Move towards player
		velocity = direction * speed
		move_and_slide()
		
		# Play run animation
		play_animation("run")
	
	# Update sprite facing direction
	update_facing_direction(direction)

func update_facing_direction(direction: Vector2):
	if direction.x != 0:
		animated_sprite.flip_h = direction.x < 0

func play_animation(anim_name: String):
	# Don't interrupt attack, hurt, or death animations unless forced
	var current_anim = animated_sprite.animation
	
	# Death animation takes priority
	if is_dead:
		if current_anim != "death":
			animated_sprite.play("death")
		return
	
	# Hurt animation takes priority
	if is_hurt:
		if current_anim != "hurt":
			animated_sprite.play("hurt")
		return
	
	# Attack animation takes priority
	if current_anim == "attack" and animated_sprite.is_playing():
		return
	
	# Play requested animation if different from current
	if current_anim != anim_name:
		animated_sprite.play(anim_name)

func attack_player():
	can_attack = false
	attack_timer.start()
	
	# Play attack animation
	play_animation("attack")
	
	# Deal damage to player (if in range)
	if player and global_position.distance_to(player.global_position) <= attack_range:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)
	
	# Optional: Attack sound
	if SettingsManager.sound_enabled:
		# Play attack sound if you have one
		pass

func take_damage(damage: int):
	if is_dead:
		return
	
	health -= damage
	
	# Set hurt state
	is_hurt = true
	hurt_timer.start()
	
	# Play hurt animation
	play_animation("hurt")
	
	# --- YOUR 4 TOGGLES ---
	
	# 1. Sound Effect
	if SettingsManager.sound_enabled:
		audio_player.play()
	
	# 2. Hit Flash
	if SettingsManager.hit_flash_enabled and hit_flash_material:
		hit_flash_material.set_shader_parameter("hit_effect", 1.0)
		await get_tree().create_timer(0.1).timeout
		hit_flash_material.set_shader_parameter("hit_effect", 0.0)
	
	# 3. Blood Particles
	if SettingsManager.blood_enabled:
		blood_particles.emitting = true
	
	# 4. Screen Shake
	if SettingsManager.screen_shake_enabled:
		var camera = get_viewport().get_camera_2d()
		if camera and camera.has_method("shake"):
			camera.shake(0.2, 5, 10)
	
	# Check for death
	if health <= 0:
		die()

func die():
	is_dead = true
	
	# Stop all movement
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	# Play death animation
	play_animation("death")
	
	# Disable collision so player can run through
	$CollisionShape2D.disabled = true
	
	# Remove enemy after animation finishes
	await get_tree().create_timer(death_remove_delay).timeout
	queue_free()

# Timer callbacks
func _on_attack_timer_timeout():
	can_attack = true

func _on_hurt_timer_timeout():
	is_hurt = false
	
	# If not dead, go back to appropriate animation
	if not is_dead:
		if player and global_position.distance_to(player.global_position) <= attack_range:
			play_animation("idle")
		else:
			play_animation("run")

# Optional: Animation finished signal
func _on_animated_sprite_2d_animation_finished():
	# When attack animation finishes, go back to idle/run
	if animated_sprite.animation == "attack":
		if player and global_position.distance_to(player.global_position) <= attack_range:
			play_animation("idle")
		else:
			play_animation("run")
