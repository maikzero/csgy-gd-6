extends CharacterBody2D

@export var speed: float = 80.0
@export var attack_range: float = 50.0

enum State { IDLE, WALK, ATTACK, HURT, DEAD }
var current_state: State = State.IDLE

var player: CharacterBody2D = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	match current_state:
		State.IDLE, State.WALK:
			handle_movement()
		State.ATTACK:
			# Don't move while attacking
			velocity = Vector2.ZERO
		State.HURT, State.DEAD:
			# Don't move when hurt or dead
			velocity = Vector2.ZERO
			return
	
	move_and_slide()

func handle_movement():
	if player == null:
		set_state(State.IDLE)
		return
	
	var direction = (player.global_position - global_position).normalized()
	var distance = global_position.distance_to(player.global_position)
	
	if distance <= attack_range:
		set_state(State.ATTACK)
		player.take_damage(10)
	else:
		set_state(State.WALK)
		velocity = direction * speed
		animated_sprite.flip_h = direction.x < 0

func set_state(new_state: State):
	if current_state == new_state:
		return
	
	current_state = new_state
	
	match new_state:
		State.IDLE:
			animated_sprite.play("idle")
		State.WALK:
			animated_sprite.play("walk")
		State.ATTACK:
			animated_sprite.play("attack")
		State.HURT:
			animated_sprite.play("hurt")
		State.DEAD:
			animated_sprite.play("death")
			set_physics_process(false)
			$CollisionShape2D.disabled = true
			await animated_sprite.animation_finished
			queue_free()

func take_damage():
	set_state(State.HURT)
	await animated_sprite.animation_finished
	set_state(State.IDLE)

func _on_animated_sprite_2d_animation_finished():
	if current_state == State.ATTACK:
		set_state(State.IDLE)
	elif current_state == State.HURT:
		set_state(State.IDLE)
