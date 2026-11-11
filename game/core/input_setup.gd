extends Node
## Registers every input action in code so the bindings live in one readable
## place. Keyboard and gamepad are both bound; rebind here.

const KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"look_up": [KEY_W, KEY_UP],
	"look_down": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE, KEY_Z],
	"attack": [KEY_J, KEY_X],
	"dodge": [KEY_SHIFT, KEY_K, KEY_C],
	"interact": [KEY_E, KEY_ENTER],
	"pause": [KEY_ESCAPE],
	"debug_panel": [KEY_F1],
	"debug_level": [KEY_F2],
	"debug_collision": [KEY_F3],
	"debug_fly": [KEY_F4],
	"debug_knife": [KEY_F5],
}

const PAD_BUTTONS := {
	"jump": [JOY_BUTTON_A],
	"attack": [JOY_BUTTON_X],
	"dodge": [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER],
	"interact": [JOY_BUTTON_Y],
	"pause": [JOY_BUTTON_START],
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"look_up": [JOY_BUTTON_DPAD_UP],
	"look_down": [JOY_BUTTON_DPAD_DOWN],
}

## action: [axis, sign]
const PAD_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"look_up": [JOY_AXIS_LEFT_Y, -1.0],
	"look_down": [JOY_AXIS_LEFT_Y, 1.0],
	"dodge": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}


func _enter_tree() -> void:
	for action: String in KEYS:
		_ensure(action)
		for key: int in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
	for action: String in PAD_BUTTONS:
		_ensure(action)
		for button: int in PAD_BUTTONS[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = button as JoyButton
			InputMap.action_add_event(action, ev)
	for action: String in PAD_AXES:
		_ensure(action)
		var ev := InputEventJoypadMotion.new()
		ev.axis = PAD_AXES[action][0] as JoyAxis
		ev.axis_value = PAD_AXES[action][1]
		InputMap.action_add_event(action, ev)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		# A small deadzone keeps the stick responsive; walk/run is analog.
		InputMap.add_action(action, 0.25)
