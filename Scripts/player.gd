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
@export var attack_damage: int = 10

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sm = $StateMachine
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_col: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var body_col: CollisionShape2D = $CollisionShape2D
@onready var camera: Camera2D = $Camera2D
@onready var attack_area: Area2D = $WeaponPivot/Hitbox
var can_deal_damage: bool = false
var attacked_enemies: Array = []  # Track enemies hit in this attack

var hit_flash_material: ShaderMaterial

func _ready() -> void:
	health = max_health
	_body_col_offset_x = body_col.position.x 
	anim_player.animation_finished.connect(_on_animation_finished)
	sm.transition_to(State.IDLE)
	anim_player.play("idle")
	
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
	
	attack_area.area_entered.connect(_on_attack_area_entered)
	attack_area.monitoring = false
	
	print("=== PLAYER ATTACK SETUP ===")
	print("Attack area: ", attack_area)
	print("Attack area monitoring: ", attack_area.monitoring)
	print("Attack area collision layer: ", attack_area.collision_layer)
	print("Attack area collision mask: ", attack_area.collision_mask)
	print("Attack area connected signals: ", attack_area.area_entered.get_connections())

func _on_attack_area_entered(area: Area2D):
	print("\n=== ATTACK DETECTION DEBUG ===")
	print("1. Area entered: ", area.name)
	print("2. Area class: ", area.get_class())
	
	var enemy = area.get_parent()
	print("3. Parent node: ", enemy.name)
	print("4. Parent class: ", enemy.get_class())
	print("5. Parent groups: ", enemy.get_groups())
	print("6. Parent has 'take_damage'? ", enemy.has_method("take_damage"))
	#print("7. Current attacking state: ", attacking)
	print("8. Can deal damage: ", can_deal_damage)
	
	# Check if already in attacked_enemies
	print("9. Already attacked? ", enemy in attacked_enemies)
	
	#if not attacking:
		#print("❌ Not attacking, ignoring")
		#return
	
	if not can_deal_damage:
		print("❌ Cannot deal damage now")
		return
	
	if enemy in attacked_enemies:
		print("❌ Already hit this enemy")
		return
	
	if enemy.has_method("take_damage"):
		print("✅ take_damage found, calling it...")
		attacked_enemies.append(enemy)
		enemy.take_damage(attack_damage)
		print("💥 Damage dealt!")
	else:
		print("❌ Enemy missing take_damage method!")
		print("   Enemy methods: ", enemy.get_method_list().map(func(m): return m["name"]))
	
	# Screen shake
	#if SettingsManager.screen_shake_enabled:
		#$Camera2D.shake(0.1, 5.0)

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
	velocity.y = jump_velocity
	_transition_play(State.JUMP, "jump")


func _enter_dash() -> void:
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
	_transition_play(State.ATTACK, "attack")
	
	attack_area.monitoring = true
	can_deal_damage = true
	attacked_enemies.clear()  # Reset for this attack
	
	if sprite.flip_h:  # Facing left
		$WeaponPivot.position = Vector2(-40, 96 - global_position.y)  # Adjust Y to ground level
	else:  # Facing right
		$WeaponPivot.position = Vector2(40, 96 - global_position.y)   # Adjust Y to ground leve
	
	# For CollisionPolygon2D - use .polygon, not .shape
	var polygon_node = $WeaponPivot/Hitbox/CollisionPolygon2D
	var points = polygon_node.polygon
	
	if points and points.size() > 0:
		# Calculate bounds from polygon points
		var min_x = 0
		var max_x = 0
		var min_y = 0
		var max_y = 0
		
		for point in points:
			min_x = min(min_x, point.x)
			max_x = max(max_x, point.x)
			min_y = min(min_y, point.y)
			max_y = max(max_y, point.y)
		
		var width = max_x - min_x
		var height = max_y - min_y
		var center = Vector2((min_x + max_x) / 2, (min_y + max_y) / 2)
		
		print("Attack area polygon points: ", points.size())
		print("Attack area bounds: width=", width, " height=", height)
		print("Attack area local center: ", center)
		print("Attack area global position: ", polygon_node.global_position)
	
	print("Attack area eneabled")
	print("Attack area monitoring: ", attack_area.monitoring)
	print("Attack area position: ", attack_area.global_position)
	print("Attack area scale: ", attack_area.scale)
	var overlapping = attack_area.get_overlapping_areas()
	print("Overlapping areas immediately: ", overlapping.size())
	for area in overlapping:
		print("  → Overlapping: ", area.name, " (parent: ", area.get_parent().name, ")")
		print("    Area layer: ", area.collision_layer)
	# Disable after attack duration
	await get_tree().create_timer(0.3).timeout  # Match attack animation
	attack_area.monitoring = false
	can_deal_damage = false


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
				_transition_play(State.DEATH, "death")
			else:
				_return_to_ground_state()
		"death":
			pass  # Freeze on last frame; game logic handles respawn/game-over
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
func take_damage(amount: int) -> void:
	# Invincible during dash and while already playing hurt animation
	if is_dead or is_invincible or sm.current_state == State.HURT:
		return
	health = max(0, health - amount)
	attack_buffered = false
	if health == 0:
		pending_death = true
	health_changed.emit(health, max_health)
	
	# Trigger screen shake
	if SettingsManager.screen_shake_enabled:
		if camera and camera.has_method("start_shake"):  
			camera.start_shake(0.2, 3.0)
		else:
			print("Camera doesn't have start_shake method!")
		
	#Your damage logic here
	print("Player took damage!")
	
	# Trigger the flash eddddd dffect
	trigger_hit_flash()
	_transition_play(State.HURT, "hurt")
	


func trigger_hit_flash():
	# Check your SettingsManager toggle
	
	if SettingsManager.hit_flash_enabled:
		# Turn flash ON
		hit_flash_material.set_shader_parameter("hit_effect", 1.0)
		
		# Turn flash OFF after 0.1 seconds
		await get_tree().create_timer(0.1).timeout
		hit_flash_material.set_shader_parameter("hit_effect", 0.0)
	else:
		print("Hit flash disabled")  # Optional debug
		
		
func _process(delta):
	if can_deal_damage:
		queue_redraw()

func _draw():
	if can_deal_damage:
		var polygon_node = $WeaponPivot/Hitbox/CollisionPolygon2D
		var points = polygon_node.polygon
		
		if points and points.size() > 2:
			# Convert to global coordinates for drawing
			var global_points = []
			var transform = polygon_node.global_transform
			for point in points:
				global_points.append(transform * point)
			
			# Draw filled polygon with transparency
			draw_colored_polygon(global_points, Color.RED)  # Just red
			# Draw outline
			draw_polyline(global_points + [global_points[0]], Color.RED, 2)
