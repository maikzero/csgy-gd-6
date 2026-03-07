extends CharacterBody2D
class_name Enemy

signal health_changed(new_health: int, max_health: int)

enum State {
	IDLE, RUN, JUMP, UP_TO_FALL, FALL,
	ATTACK, ATTACK2, DASH, DASH_ATTACK,
	HURT, DEATH
}

@export var speed: float = 100.0
@export var jump_velocity: float = -350.0
@export var dash_speed: float = 200.0
@export var dash_duration: float = 0.275
@export var max_health: int = 100

var health: int = 10
var is_dead: bool = false
var is_invincible: bool = false  # true during dash (i-frames)
var pending_death: bool = false  # set when hurt animation should lead into death
var attack_buffered: bool = false  # attack pressed during attack anim → triggers attack2
var facing_right: bool = true
var _dash_timer: float = 0.0
var _body_col_offset_x: float  # original x offset of body CollisionShape2D
@export var attack_damage: int = 2

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sm = $StateMachine
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_col: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var body_col: CollisionShape2D = $CollisionShape2D
@onready var camera: Camera2D = $Camera2D
@onready var attack_area: Area2D = $WeaponPivot/Hitbox
@onready var hitbox_col: CollisionShape2D = $WeaponPivot/Hitbox/CollisionShape2D
@onready var dash_sfx: AudioStreamPlayer = $DashSFX
@onready var attack1_sfx: AudioStreamPlayer = $AttackSFX
@onready var attack2_sfx: AudioStreamPlayer = $AttackSFX2
@onready var dash_attack_sfx: AudioStreamPlayer = $AttackSFX3
@onready var jump_sfx: AudioStreamPlayer = $JumpSFX
@onready var hurt_sfx: AudioStreamPlayer = $HurtSFX
@onready var game_over_sfx: AudioStreamPlayer = $GameOverSFX

const BLOOD_PARTICLES = preload("res://Scenes/blood_particles.tscn")

var hit_flash_material: ShaderMaterial

func _ready() -> void:
	health = max_health
	_body_col_offset_x = body_col.position.x 
	anim_player.animation_finished.connect(_on_animation_finished)
	sm.transition_to(State.IDLE)
	anim_player.play("idle")
	
	attack_area.body_entered.connect(_on_hitbox_body_entered)
	
	if sprite.material is ShaderMaterial:
		hit_flash_material = sprite.material
		print("Shader material found!")  # Helpful for debugging
	else:
		print("No shader material assigned to sprite!")
		# If no material, create one (optional)
		var new_material = ShaderMaterial.new()
		new_material.shader = preload("res://Shaders/Player.gdshader")
		sprite.material = new_material
		hit_flash_material = new_material
	
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		var damage := attack_damage * 2 if sm.current_state == State.DASH_ATTACK else attack_damage
		body.take_damage(damage)
		if sm.current_state == State.DASH_ATTACK and SettingsManager.screen_shake_enabled:
			camera.shake(0.1, 2.0)


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and "attack_damage" in body and body.is_attacking:
		take_damage(body.attack_damage, body.global_position)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	_process_state()
	_update_facing_visuals()
	move_and_slide()



func _process_state() -> void:
	match sm.current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, speed)
			if Input.is_action_just_pressed("jump") and is_on_floor():
				_enter_jump()
			elif Input.is_action_just_pressed("dash"):
				_enter_dash()
			elif Input.is_action_just_pressed("attack"):
				_enter_attack()
			elif Input.get_axis("left", "right") != 0.0:
				var dir := Input.get_axis("left", "right")
				facing_right = dir > 0
				_transition_play(State.RUN, "run")

		State.RUN:
			var dir := Input.get_axis("left", "right")
			if Input.is_action_just_pressed("jump") and is_on_floor():
				_enter_jump()
			elif Input.is_action_just_pressed("dash"):
				_enter_dash()
			elif Input.is_action_just_pressed("attack"):
				_enter_attack()
			elif dir != 0.0:
				velocity.x = dir * speed
				facing_right = dir > 0
			else:
				velocity.x = move_toward(velocity.x, 0, speed)
				_transition_play(State.IDLE, "idle")

		State.JUMP:
			_apply_air_movement()
			if velocity.y >= 0.0:
				_transition_play(State.UP_TO_FALL, "up_to_fall")

		State.UP_TO_FALL:
			_apply_air_movement()
			# Transition to FALL handled by animation_finished

		State.FALL:
			_apply_air_movement()
			if is_on_floor():
				if Input.get_axis("left", "right") != 0.0:
					_transition_play(State.RUN, "run")
				else:
					_transition_play(State.IDLE, "idle")

		State.ATTACK:
			velocity.x = move_toward(velocity.x, 0, speed)
			if Input.is_action_just_pressed("attack"):
				attack_buffered = true
			# Transition to ATTACK2 or IDLE handled by animation_finished

		State.ATTACK2:
			velocity.x = move_toward(velocity.x, 0, speed)
			# Transition to IDLE handled by animation_finished

		State.DASH:
			# Cancel gravity and propel in facing direction (i-frames active)
			if _dash_timer > 0.0:
				_dash_timer -= get_physics_process_delta_time()
				velocity.x = (1.0 if facing_right else -1.0) * dash_speed
				velocity.y = 0.0
			else:
				velocity.x = move_toward(velocity.x, 0, speed)
			if Input.is_action_just_pressed("attack"):
				# End i-frames and launch dash_attack
				is_invincible = false
				hurtbox_col.disabled = false
				if SettingsManager.sound_enabled:
					dash_attack_sfx.play()
				_transition_play(State.DASH_ATTACK, "dash_attack")
			# Transition to IDLE handled by animation_finished (if attack not pressed)

		State.DASH_ATTACK:
			velocity.x = move_toward(velocity.x, 0, speed)
			# Transition to IDLE handled by animation_finished

		State.HURT:
			velocity.x = move_toward(velocity.x, 0, speed * 3.0)
			# Transition to IDLE or DEATH handled by animation_finished

		State.DEATH:
			velocity.x = move_toward(velocity.x, 0, speed)
			# No further transitions


# ── Input helpers ───────────────────────────────────────────────────────────

func _enter_jump() -> void:
	if SettingsManager.sound_enabled:
		jump_sfx.play()
	velocity.y = jump_velocity
	_transition_play(State.JUMP, "jump")


func _enter_dash() -> void:
	if SettingsManager.sound_enabled:
		dash_sfx.play()
	var dir := Input.get_axis("left", "right")
	if dir != 0.0:
		facing_right = dir > 0
	is_invincible = true
	attack_buffered = false
	_dash_timer = dash_duration
	velocity.y = 0.0
	hurtbox_col.disabled = true
	_transition_play(State.DASH, "dash")


func _enter_attack() -> void:
	attack_buffered = false
	if SettingsManager.sound_enabled:
		attack1_sfx.play()
	_transition_play(State.ATTACK, "attack")


# Only transitions if we're not already in new_state (prevents animation restart).
func _transition_play(new_state: State, anim_name: String) -> void:
	if sm.current_state == new_state:
		return
	sm.transition_to(new_state)
	anim_player.play(anim_name)


func _apply_air_movement() -> void:
	var dir := Input.get_axis("left", "right")
	if dir != 0.0:
		velocity.x = dir * speed
		facing_right = dir > 0


func _update_facing_visuals() -> void:
	sprite.flip_h = not facing_right
	# Mirror weapon hitbox, hurtbox, and body collision to match facing direction
	var dir_scale := 1.0 if facing_right else -1.0
	weapon_pivot.scale.x = dir_scale
	hurtbox.scale.x = dir_scale
	body_col.position.x = _body_col_offset_x * dir_scale


# ── Animation callbacks ─────────────────────────────────────────────────────

func _on_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"attack":
			if attack_buffered:
				attack_buffered = false
				if SettingsManager.sound_enabled:
					attack2_sfx.play()
				_transition_play(State.ATTACK2, "attack2")
			else:
				_return_to_ground_state()
		"attack2":
			_return_to_ground_state()
		"dash":
			is_invincible = false
			hurtbox_col.disabled = false
			_return_to_ground_state()
		"dash_attack":
			_return_to_ground_state()
		"hurt":
			if pending_death:
				pending_death = false
				is_dead = true
				if SettingsManager.sound_enabled:
					game_over_sfx.play()
				_transition_play(State.DEATH, "death")
			else:
				_return_to_ground_state()
		"death":
			pass
		"up_to_fall":
			_transition_play(State.FALL, "fall")


# Returns to idle/run (on floor) or fall (in air) after a non-looping animation ends.
func _return_to_ground_state() -> void:
	if not is_on_floor():
		_transition_play(State.FALL, "fall")
		return
	if Input.get_axis("left", "right") != 0.0:
		_transition_play(State.RUN, "run")
	else:
		_transition_play(State.IDLE, "idle")


# ── Public API ───────────────────────────────────────────────────────────────

# Call this from enemy hitbox signals or other damage sources.
func take_damage(amount: int, from: Vector2 = Vector2.ZERO) -> void:
	# Invincible during dash and while already playing hurt animation
	if is_dead or is_invincible or sm.current_state == State.HURT:
		return
	health = max(0, health - amount)
	attack_buffered = false
	if health == 0:
		pending_death = true
	health_changed.emit(health, max_health)
	
	if SettingsManager.sound_enabled:
		hurt_sfx.play()
	trigger_hit_flash()
	if SettingsManager.blood_enabled:
		var dir := (global_position - from).normalized() if from != Vector2.ZERO else Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		_spawn_blood(dir)
	if SettingsManager.screen_shake_enabled:
		camera.shake(0.2, 3.0)
	_transition_play(State.HURT, "hurt")
	
func trigger_hit_flash():
	# Check your SettingsManager toggle
	
	if SettingsManager.hit_flash_enabled:
		# Turn flash ON
		hit_flash_material.set_shader_parameter("hit_effect", 0.5)
		
		# Turn flash OFF after 0.1 seconds
		await get_tree().create_timer(0.1).timeout
		hit_flash_material.set_shader_parameter("hit_effect", 0.0)
	else:
		print("Hit flash disabled")  # Optional debug

func _spawn_blood(direction: Vector2) -> void:
	var blood = BLOOD_PARTICLES.instantiate()
	blood.global_position = global_position
	blood.rotation = direction.angle()
	get_parent().add_child(blood)
