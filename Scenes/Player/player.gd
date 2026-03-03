extends CharacterBody2D 

@onready var sprite: Sprite2D = $Warrior  # Make sure this path is correct!
var hit_flash_material: ShaderMaterial

func _ready():
	# Get reference to the shader material
	if sprite.material is ShaderMaterial:
		hit_flash_material = sprite.material
		print("Shader material found!")  # Helpful for debugging
	else:
		print("No shader material assigned to sprite!")
		# If no material, create one (optional)
		var new_material = ShaderMaterial.new()
		new_material.shader = preload("res://Scenes/Player/Player.gdshader")
		sprite.material = new_material
		hit_flash_material = new_material

func take_damage():
	# Your damage logic here
	print("Player took damage!")
	
	# Trigger the flash effect
	trigger_hit_flash()

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
