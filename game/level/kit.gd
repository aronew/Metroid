class_name Kit
## The environment kit: textures and measurements written by tools/build_kit.py.
##
##   Kit.tex("wreck/heap")    -> Texture2D
##   Kit.meta("wreck/heap")   -> {"size": [w, h], "top": ..., ...}
##
## Keys are "<group>/<name>" as listed in assets/kit/kit.json and drawn in
## docs/kit-pieces.png.

const INDEX := "res://assets/kit/kit.json"

## Candle-flame loop timing (frames at 60 ticks/s), as the kit specifies.
const FLAME_TICKS := [6, 6, 5, 5, 6, 6, 5, 6]
const FLAME_LOOP := 45          # sum of FLAME_TICKS
const SWAY_TICKS := 8

static var _meta: Dictionary = {}
static var _tex: Dictionary = {}


static func _load() -> void:
	if _meta.is_empty() and FileAccess.file_exists(INDEX):
		_meta = JSON.parse_string(FileAccess.get_file_as_string(INDEX))


static func has(key: String) -> bool:
	_load()
	return _meta.has(key)


static func meta(key: String) -> Dictionary:
	_load()
	return _meta.get(key, {})


static func size(key: String) -> Vector2:
	var s: Array = meta(key).get("size", [1, 1])
	return Vector2(s[0], s[1])


static func tex(key: String) -> Texture2D:
	if not _tex.has(key):
		var m := meta(key)
		_tex[key] = load(m["path"]) if m.has("path") else null
	return _tex[key]


## Which frame of the candle loop to show at `ticks`.
static func flame_frame(ticks: int) -> int:
	var t := ticks % FLAME_LOOP
	for i in FLAME_TICKS.size():
		t -= FLAME_TICKS[i]
		if t < 0:
			return i
	return 0


## Draws one flame of the loop with its base at `base` and `height` px tall.
static func draw_flame(ci: CanvasItem, base: Vector2, height: float, ticks: int, alpha: float = 1.0) -> void:
	var key := "flame/f%d" % flame_frame(ticks)
	var t := tex(key)
	if t == null:
		return
	var anchor: Array = meta(key)["anchor"]
	# A calm flame (frame 0) fills 0.75 of its cell; size the loop by that,
	# so the taller frames still flare above it.
	var s := height / (t.get_height() * 0.75)
	var rect := Rect2(base - Vector2(anchor[0], anchor[1]) * s, t.get_size() * s)
	ci.draw_texture_rect(t, rect, false, Color(1, 1, 1, alpha))
