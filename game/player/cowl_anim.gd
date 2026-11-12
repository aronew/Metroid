class_name CowlAnim
## Cowl's clips and effects as cut by tools/build_cowl_sprites.py.
##
## Frames are stored at 2x game size; each frame's (ox, oy) is where its
## top-left lands relative to Cowl's feet (or, for effects, the effect's
## origin), in game px, facing right.

const INDEX := "res://assets/cowl/cowl_anim.json"

static var data: Dictionary = {}
static var _tex: Dictionary = {}


static func load_data() -> void:
	if data.is_empty():
		data = JSON.parse_string(FileAccess.get_file_as_string(INDEX))


static func clip(name: String) -> Dictionary:
	load_data()
	return data["clips"].get(name, {})


static func fx(name: String) -> Dictionary:
	load_data()
	return data["fx"].get(name, {})


static func tex(dir: String, file: String) -> Texture2D:
	var path := "res://assets/cowl/%s/%s" % [dir, file]
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]


## Frame index at `ticks` into a clip with these tick lengths (holds the last).
static func frame_at(ticks_list: Array, ticks: float) -> int:
	var t := ticks
	for i in ticks_list.size():
		t -= float(ticks_list[i])
		if t < 0.0:
			return i
	return ticks_list.size() - 1


static func length(ticks_list: Array) -> int:
	var n := 0
	for t in ticks_list:
		n += int(t)
	return n
