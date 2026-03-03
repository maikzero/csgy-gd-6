extends Node2D

# Generic integer-based state machine.
# The player defines the State enum and passes int values here.
var current_state: int = 0
var previous_state: int = 0

signal state_changed(from_state: int, to_state: int)

func transition_to(new_state: int) -> void:
	if current_state == new_state:
		return
	previous_state = current_state
	current_state = new_state
	state_changed.emit(previous_state, current_state)
