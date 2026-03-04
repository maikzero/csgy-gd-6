extends MarginContainer

@export var delay_before_drain: float = 0.4
@export var drain_duration: float = 0.6

@onready var health_bar: ProgressBar = $HealthBar
@onready var delay_bar: ProgressBar = $DelayBar

var _tween: Tween


func _ready() -> void:
	await get_tree().process_frame
	_connect_to_player()


func _connect_to_player() -> void:
	var player = get_tree().current_scene.get_node_or_null("Player")
	if player == null:
		push_error("HealthBar: Player node not found.")
		return

	print("HealthBar: connected to player, max_health=", player.max_health)

	health_bar.max_value = player.max_health
	delay_bar.max_value = player.max_health
	health_bar.value = player.health
	delay_bar.value = player.health

	player.health_changed.connect(_on_health_changed)

	var sm = get_tree().current_scene.get_node_or_null("UI_Layer/SettingsManager")
	if sm:
		sm.delay_bar_toggled.connect(_on_delay_bar_toggled)


func _on_delay_bar_toggled(enabled: bool) -> void:
	delay_bar.visible = enabled
	if not enabled and _tween:
		_tween.kill()


func _on_health_changed(new_health: int, max_health: int) -> void:
	print("HealthBar: health changed to ", new_health)
	health_bar.value = new_health

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(delay_before_drain)
	_tween.tween_property(delay_bar, "value", float(new_health), drain_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
