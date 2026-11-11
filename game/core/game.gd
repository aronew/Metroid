extends Node
## Session state and the few global effects (hit-stop, messages, flags).
## Kept deliberately small: anything a save file would hold lives here.

signal message_requested(text: String, seconds: float)
signal knife_acquired
signal player_health_changed(current: int, maximum: int)
signal player_died
signal flag_changed(flag: String)
signal camera_shake(amount: float)

const TILE := 64.0

var has_knife := false
var flags: Dictionary = {}
var checkpoint_position := Vector2.ZERO
var has_checkpoint := false
var debug_collision := false

var _hitstop_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _hitstop_left > 0.0:
		# Hit-stop runs on real time, since the tree's time is what it stops.
		_hitstop_left -= delta / maxf(Engine.time_scale, 0.001)
		if _hitstop_left <= 0.0:
			Engine.time_scale = 1.0


## Freeze the world for a few frames so a blow has weight.
func hitstop(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_hitstop_left = maxf(_hitstop_left, seconds)
	Engine.time_scale = 0.05


func shake(amount: float) -> void:
	camera_shake.emit(amount)


func say(text: String, seconds: float = 3.5) -> void:
	message_requested.emit(text, seconds)


func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value
	flag_changed.emit(flag)


func get_flag(flag: String) -> Variant:
	return flags.get(flag, false)


func give_knife() -> void:
	if has_knife:
		return
	has_knife = true
	knife_acquired.emit()


func set_checkpoint(pos: Vector2) -> void:
	checkpoint_position = pos
	has_checkpoint = true


func reset_session() -> void:
	has_knife = false
	flags.clear()
	has_checkpoint = false
	Engine.time_scale = 1.0
	_hitstop_left = 0.0
