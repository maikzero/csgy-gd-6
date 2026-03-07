extends GPUParticles2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	emitting = true
	# Wait for the particles to finish, then queue_free
	await get_tree().create_timer(lifetime + 0.5).timeout
	queue_free()
