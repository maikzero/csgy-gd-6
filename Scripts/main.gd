extends Node2D

@onready var player = $Player
@onready var restart_button: Button = $UI_Layer/RestartButton

func _ready() -> void:
	restart_button.visible = false
	player.died.connect(_on_player_died)
	restart_button.pressed.connect(_on_restart_pressed)

func _on_player_died() -> void:
	restart_button.visible = true

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
