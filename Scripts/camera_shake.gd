extends Camera2D

# Shake parameters
var shake_duration: float = 0.0
var shake_intensity: float = 10.0
var original_offset: Vector2 = Vector2.ZERO

func _ready():
	original_offset = offset

func _process(delta):
	if shake_duration > 0:
		shake_duration -= delta
		
		if SettingsManager.screen_shake_enabled:
			# Generate random shake
			offset = Vector2(
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity)
			)
		else:
			offset = original_offset
	else:
		offset = original_offset

# Call this function to start shaking
func start_shake(duration: float = 0.2, intensity: float = 10.0):
	shake_duration = duration
	shake_intensity = intensity
	print("Shake started: ", duration, "s at intensity ", intensity)
