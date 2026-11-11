class_name Hud
extends CanvasLayer
## Health, messages, the screen fade and the F1 movement-tuning panel.

const PRESETS := {
	"Cowl (default)": "res://game/player/presets/cowl_default.tres",
	"Snappy": "res://game/player/presets/snappy.tres",
	"Weighty": "res://game/player/presets/weighty.tres",
}
## [property, min, max, step]
const TUNABLES := [
	["run_speed", 4.0, 14.0, 0.1], ["accel_time", 0.0, 0.4, 0.005],
	["decel_time", 0.0, 0.4, 0.005], ["turn_time", 0.0, 0.3, 0.005],
	["jump_height", 1.5, 6.0, 0.05], ["time_to_apex", 0.2, 0.6, 0.01],
	["fall_gravity_mult", 1.0, 3.0, 0.05], ["jump_cut_mult", 0.1, 1.0, 0.02],
	["apex_gravity_mult", 0.2, 1.0, 0.05], ["max_fall_speed", 12.0, 40.0, 0.5],
	["jump_buffer", 0.0, 0.3, 0.01], ["coyote_time", 0.0, 0.3, 0.01],
	["air_accel_time", 0.0, 0.5, 0.01], ["air_decel_time", 0.0, 0.6, 0.01],
	["air_turn_time", 0.0, 0.4, 0.01], ["dodge_distance", 1.0, 7.0, 0.1],
	["dodge_time", 0.1, 0.5, 0.01], ["dodge_cooldown", 0.0, 1.0, 0.05],
]

var cowl: Cowl
var main: Node

var _health: Control
var _message: Label
var _prompt: Label
var _fade: ColorRect
var _panel: PanelContainer
var _readout: Label
var _sliders: Dictionary = {}
var _message_left := 0.0
var _hp := 5
var _hp_max := 5
var _hp_flash := 0.0

# telemetry
var _jump_from := Vector2.ZERO
var _jump_top := 0.0
var _in_jump := false
var _last_jump := Vector2.ZERO
var _last_air := 0.0
var _peak_speed := 0.0


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_health = Control.new()
	_health.position = Vector2(54, 48)
	_health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health.draw.connect(_draw_health)
	root.add_child(_health)

	_message = _make_label(34, Color(0.9, 0.88, 1.0))
	_message.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_message.offset_left = -800
	_message.offset_right = 800
	_message.offset_top = -210
	_message.offset_bottom = -110
	_message.modulate.a = 0.0
	root.add_child(_message)

	_prompt = _make_label(26, Color(0.78, 0.76, 0.95))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -600
	_prompt.offset_right = 600
	_prompt.offset_top = -100
	_prompt.offset_bottom = -50
	_prompt.modulate.a = 0.0
	root.add_child(_prompt)

	_fade = ColorRect.new()
	_fade.color = Color(0.008, 0.006, 0.015, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)

	_build_panel(root)

	Game.message_requested.connect(_on_message)
	Game.player_health_changed.connect(_on_health)


func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", Color(0.02, 0.01, 0.05))
	l.add_theme_constant_override(&"outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func bind(new_cowl: Cowl, new_main: Node) -> void:
	cowl = new_cowl
	main = new_main
	_hp = cowl.max_health
	_hp_max = cowl.max_health
	cowl.jumped.connect(func() -> void:
		_jump_from = cowl.global_position
		_jump_top = cowl.global_position.y
		_in_jump = true)
	cowl.landed.connect(func(_s: float) -> void:
		if _in_jump:
			_last_jump = Vector2(absf(cowl.global_position.x - _jump_from.x), _jump_from.y - _jump_top) / Game.TILE
			_last_air = cowl.air_time
			_in_jump = false)
	_sync_sliders()
	_health.queue_redraw()
	_fade.color.a = 0.0


# =================================================================== messages
func _on_message(text: String, seconds: float) -> void:
	_message.text = text
	_message_left = seconds


func set_prompt(text: String) -> void:
	_prompt.text = text


func fade(to: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", to, seconds)
	await tw.finished


func _on_health(current: int, maximum: int) -> void:
	if current < _hp:
		_hp_flash = 1.0
	_hp = current
	_hp_max = maximum
	_health.queue_redraw()


func _draw_health() -> void:
	# Pale-blue pips, the colour of Cowl's eyes.
	for i in _hp_max:
		var c := Vector2(i * 46.0, 0.0)
		var full := i < _hp
		_health.draw_circle(c, 17.0, Color(0.02, 0.02, 0.05, 0.75))
		if full:
			_health.draw_circle(c, 12.0, Color(0.62, 0.9, 1.0).lerp(Color.WHITE, _hp_flash))
			_health.draw_circle(c + Vector2(-3, -3), 4.0, Color(1, 1, 1, 0.75))
		else:
			_health.draw_arc(c, 11.0, 0.0, TAU, 24, Color(0.4, 0.45, 0.6, 0.6), 2.5, true)


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.001)
	_message_left -= real
	_message.modulate.a = move_toward(_message.modulate.a, 1.0 if _message_left > 0.0 else 0.0, real * 2.5)
	_prompt.modulate.a = move_toward(_prompt.modulate.a, 1.0 if _prompt.text != "" else 0.0, real * 5.0)
	if _hp_flash > 0.0:
		_hp_flash = maxf(_hp_flash - real * 3.0, 0.0)
		_health.queue_redraw()
	_health.visible = cowl != null and cowl.state != Cowl.State.CUTSCENE
	if cowl != null and _panel.visible:
		if _in_jump:
			_jump_top = minf(_jump_top, cowl.global_position.y)
		_peak_speed = maxf(_peak_speed * 0.995, absf(cowl.velocity.x) / Game.TILE)
		_readout.text = "%s\nspeed %.2f t/s   vy %.1f t/s   %s\nlast jump: rise %.2f t, travel %.2f t, air %.2f s\nlevel: %s   F2 switch level   F3 collision   F4 fly   F5 knife" % [
			cowl.config.describe(), absf(cowl.velocity.x) / Game.TILE, cowl.velocity.y / Game.TILE,
			"ground" if cowl.is_on_floor() else "air",
			_last_jump.y, _last_jump.x, _last_air, main.get("level_name")]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_panel"):
		_panel.visible = not _panel.visible


# ================================================================ tuning panel
func _build_panel(root: Control) -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -560
	_panel.offset_top = 20
	_panel.offset_right = -20
	_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.08, 0.88)
	style.set_content_margin_all(14)
	style.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override(&"panel", style)
	root.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "MOVEMENT TUNING   (F1 to close)"
	title.add_theme_font_size_override(&"font_size", 18)
	box.add_child(title)

	var row := HBoxContainer.new()
	box.add_child(row)
	for preset_name: String in PRESETS:
		var b := Button.new()
		b.text = preset_name
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_load_preset.bind(preset_name))
		row.add_child(b)

	for t: Array in TUNABLES:
		var line := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = t[0]
		name_label.custom_minimum_size.x = 190
		name_label.add_theme_font_size_override(&"font_size", 15)
		var slider := HSlider.new()
		slider.min_value = t[1]
		slider.max_value = t[2]
		slider.step = t[3]
		slider.custom_minimum_size.x = 240
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_NONE
		var value_label := Label.new()
		value_label.custom_minimum_size.x = 64
		value_label.add_theme_font_size_override(&"font_size", 15)
		slider.value_changed.connect(_on_slider.bind(t[0], value_label))
		line.add_child(name_label)
		line.add_child(slider)
		line.add_child(value_label)
		box.add_child(line)
		_sliders[t[0]] = [slider, value_label]

	_readout = Label.new()
	_readout.add_theme_font_size_override(&"font_size", 15)
	_readout.add_theme_color_override(&"font_color", Color(0.7, 0.9, 1.0))
	box.add_child(_readout)


func _on_slider(value: float, property: String, value_label: Label) -> void:
	value_label.text = "%.3f" % value
	if cowl != null:
		cowl.config.set(property, value)


func _sync_sliders() -> void:
	if cowl == null:
		return
	for property: String in _sliders:
		var slider: HSlider = _sliders[property][0]
		slider.set_value_no_signal(cowl.config.get(property))
		(_sliders[property][1] as Label).text = "%.3f" % float(cowl.config.get(property))


func _load_preset(preset_name: String) -> void:
	if cowl == null:
		return
	# Duplicate, so sliders never write into the preset file's resource.
	cowl.config = (load(PRESETS[preset_name]) as MovementConfig).duplicate()
	_sync_sliders()
