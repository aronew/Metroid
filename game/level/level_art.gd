extends Node2D
## The art pass: dresses a Level's data with the environment kit. It never
## collides, and it never adds a shape the collision does not have.
##
## Layers, far to near (z_index):
##
##   screen  haze gradient                                  (fixed to the screen)
##   para    far arcades, middle galleries, near arcade      (kit W03-W05, parallax)
##   -60     room walls by mood (kit W18-W25, W06), windows (W17), stains
##   -50     painted room plates (kit P_*), their candle flames
##   -45     piers (W15) and cobwebs
##   -28     candelabra and lamps (W35) with the flame loop (W36)
##    -5     railings (W14), floor decals (W39)
##     0     the collision mass in the kit's own ink, then its skin: floor
##           tops (W08), ceilings (W09), wall faces (W10), corners (W11), stairs (W13)
##     1     wreckage fitted to the masses it stands for (W26-W29), vault ribs (W16)
##     2     door frames (W12)
##    10     Cowl and the creatures (their own scripts)
##    20     hanging moss (W37) and the sway loop (W38)
##   screen  dust, vignette
##
## Pieces are fitted to the collision, to an entity's rectangle or to a height
## relative to Cowl, never drawn at an arbitrary scale: the kit's sheets were
## not exported at one consistent scale.

const TILE := 64.0
const INK := Color("060713")         # the kit's mass colour (W08/W10/W11 fill)
const COWL_H := 124.0

## room mood -> wall texture, floor top, ceiling, wall face
const MOODS := {
	"bedroom": {"wall": "walls/bedroom", "floor": "carved", "ceiling": "ribs", "face": "pilaster", "windows": "lancet"},
	"hall_upper": {"wall": "walls/common", "floor": "carved", "ceiling": "ribs", "face": "pilaster", "windows": "lancet"},
	"kitchen": {"wall": "walls/common", "floor": "flagstone", "ceiling": "beams", "face": "pilaster"},
	"dining": {"wall": "walls/common", "floor": "carved", "ceiling": "ribs", "face": "pilaster", "windows": "lancet"},
	"living": {"wall": "walls/common", "floor": "carved", "ceiling": "ribs", "face": "pilaster"},
	"study": {"wall": "walls/library", "floor": "carved", "ceiling": "beams", "face": "pilaster"},
	"library": {"wall": "walls/library", "floor": "carved", "ceiling": "ribs", "face": "pilaster"},
	"attic": {"wall": "walls/attic", "floor": "carved", "ceiling": "beams", "face": "stone", "windows": "dormer"},
	"pantry": {"wall": "walls/cellar", "floor": "flagstone", "ceiling": "stone", "face": "stone", "windows": "cellar_bars"},
	"storage": {"wall": "walls/cellar", "floor": "flagstone", "ceiling": "stone", "face": "stone"},
	"workshop": {"wall": "walls/cellar", "floor": "flagstone", "ceiling": "iron", "face": "stone", "windows": "cellar_bars"},
	"boiler": {"wall": "walls/cellar", "floor": "flagstone", "ceiling": "iron", "face": "stone"},
	"lab": {"wall": "walls/lab", "floor": "iron", "ceiling": "iron", "face": "stone", "windows": "porthole"},
	"conservatory": {"wall": "walls/conservatory", "floor": "flagstone", "ceiling": "stone", "face": "stone"},
	"tower": {"wall": "walls/tower", "floor": "flagstone", "ceiling": "stone", "face": "stone", "windows": "lancet"},
	"grand_hall": {"wall": "", "floor": "carved", "ceiling": "ribs", "face": "pilaster"},
	"undercroft": {"wall": "parallax/undercroft", "floor": "flagstone", "ceiling": "stone", "face": "stone"},
}
## Heights in game px for pieces placed by size rather than fitted.
const HEIGHTS := {
	"lights/candelabrum_3": 150.0, "lights/candelabrum_5": 185.0, "lights/candle_table": 132.0,
	"lights/sconce": 84.0, "lights/father_lamp": 120.0, "lights/chandelier_small": 170.0,
	"lights/candle_stubs": 46.0, "lights/candelabrum_toppled": 58.0,
	"decals/cobweb_L": 120.0, "decals/cobweb_R": 120.0, "decals/damp_stain": 180.0,
	"decals/wall_crack": 130.0, "decals/ceiling_roots": 170.0,
}
## Floor decals are capped to a quarter tile at the depth of play.
const FLOOR_DECAL_MAX := 15.0
## Moss clump widths in game px (the kit's stated widths at 64 px a tile).
const MOSS_W := [30.0, 40.0, 80.0, 100.0, 150.0, 200.0, 22.0, 240.0]
## Nothing hangs lower than this above the floor beneath it.
const CLEAR := 2.5 * TILE

var level: Level
var data: Dictionary
var _w := 0
var _h := 0
var _solid: PackedByteArray
var _dressed: PackedByteArray        # mass cells covered by wreckage art
var _room_of: PackedInt32Array       # room index per cell (-1 outside)
var _glow_tex: Texture2D
var _lights: Array = []              # glow sprites to flicker
var _flames: Array = []              # {"node", "pts": [[pos, height]], "ph"}
var _sways: Array = []               # {"pos", "h", "ph", "flip"}
var _sway_node: Node2D
var _t := 0.0
var _ticks := 0
var _dust: CPUParticles2D
var _plate_spans: Dictionary = {}    # room index -> Array of Vector2 (x spans covered)


func dress(lvl: Level) -> void:
	level = lvl
	data = lvl.data
	_w = int(data["w"])
	_h = int(data["h"])
	_build_grids()
	_glow_tex = _make_glow()
	_build_sky()
	_build_parallax()
	_build_walls()
	_build_plates()
	_build_piers()
	_build_lights()
	_build_mass()
	_build_wreckage()
	_build_frames()
	_build_moss()
	_build_overlay()


# ====================================================================== grids
func _build_grids() -> void:
	_solid = PackedByteArray()
	_solid.resize(_w * _h)
	_dressed = PackedByteArray()
	_dressed.resize(_w * _h)
	_room_of = PackedInt32Array()
	_room_of.resize(_w * _h)
	_room_of.fill(-1)
	for r: Array in data["solids"]:
		for y in range(int(r[1]), int(r[1] + r[3])):
			for x in range(int(r[0]), int(r[0] + r[2])):
				_solid[y * _w + x] = 1
	for p: Dictionary in data.get("props", []):
		if p["sprite"] == "wreck":
			var m: Array = p["mass"]
			for y in range(int(m[1]), int(m[1] + m[3])):
				for x in range(int(m[0]), int(m[0] + m[2])):
					_dressed[y * _w + x] = 1
	# smallest room wins
	var rooms: Array = data["rooms"]
	var order := range(rooms.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return rooms[a]["w"] * rooms[a]["h"] > rooms[b]["w"] * rooms[b]["h"])
	for i: int in order:
		var r: Dictionary = rooms[i]
		for y in range(maxi(int(r["y"]) - 1, 0), mini(int(r["y"] + r["h"]) + 1, _h)):
			for x in range(maxi(int(r["x"]), 0), mini(int(r["x"] + r["w"]), _w)):
				_room_of[y * _w + x] = i


func solid(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return true
	return _solid[y * _w + x] == 1


func dressed(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return false
	return _dressed[y * _w + x] == 1


func mood_at(x: int, y: int) -> Dictionary:
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return MOODS["hall_upper"]
	var i := _room_of[y * _w + x]
	if i < 0:
		return MOODS["hall_upper"]
	return MOODS.get(data["rooms"][i].get("mood", ""), MOODS["hall_upper"])


func room_index(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return -1
	return _room_of[y * _w + x]


## Open cells straight down from (x, y), up to `limit`.
func clearance(x: int, y: int, limit: int = 12) -> int:
	var n := 0
	while n < limit and not solid(x, y + n):
		n += 1
	return n


## A gallery: a floor slab with open air close beneath it, in the same room
## (a storey floor with another room under it is not a gallery).
func is_gallery(x: int, y: int) -> bool:
	for k in range(1, 5):
		if not solid(x, y + k):
			return room_index(x, y + k) >= 0 and room_index(x, y + k) == room_index(x, y - 1)
	return false


func _hash(a: int, b: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663))


func _make_glow() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.32), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex


func _drawer(z: int, fn: Callable, parent: Node = self, repeat := CanvasItem.TEXTURE_REPEAT_MIRROR) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	n.texture_repeat = repeat
	n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	n.draw.connect(fn.bind(n))
	parent.add_child(n)
	return n


## Draw `key` into `rect`, optionally mirrored.
func _put(n: CanvasItem, key: String, rect: Rect2, flip := false, modulate := Color.WHITE) -> void:
	var t := Kit.tex(key)
	if t == null:
		return
	if flip:
		rect = Rect2(rect.position.x + rect.size.x, rect.position.y, -rect.size.x, rect.size.y)
	n.draw_texture_rect(t, rect, false, modulate)


## Draw `key` at a height, standing with its bottom centre on `foot`.
func _stand(n: CanvasItem, key: String, foot: Vector2, height: float, flip := false) -> Rect2:
	var s := height / Kit.size(key).y
	var size := Kit.size(key) * s
	var rect := Rect2(foot - Vector2(size.x * 0.5, size.y), size)
	_put(n, key, rect, flip)
	return rect


# ======================================================================== sky
func _build_sky() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -100
	add_child(layer)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.42, 0.68, 1.0])
	g.colors = PackedColorArray([Color("0b0b1f"), Color("2a2c58"), Color("3b3f78"), Color("141632")])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 8
	tex.height = 256
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)


# =================================================================== parallax
func _build_parallax() -> void:
	# The kit's three depths of the same Gothic arcade. Horizontal scroll is
	# stronger than vertical, so climbing never makes the house swim.
	var world := Vector2(_w, _h) * TILE
	var centre_y := world.y * 0.45
	var layers := [
		{"key": "parallax/far_arcades", "scroll": Vector2(0.08, 0.04), "scale": 1.5, "tint": Color(0.82, 0.82, 0.95, 1.0)},
		{"key": "parallax/middle_galleries", "scroll": Vector2(0.2, 0.1), "scale": 1.15, "tint": Color(0.72, 0.72, 0.88, 0.85)},
		{"key": "parallax/near_arcade", "scroll": Vector2(0.38, 0.2), "scale": 1.25, "tint": Color(0.52, 0.52, 0.68, 0.8)},
	]
	var i := 0
	for l: Dictionary in layers:
		var p := Parallax2D.new()
		p.scroll_scale = l["scroll"]
		p.z_index = -90 + i
		p.ignore_camera_scroll = false
		add_child(p)
		var key: String = l["key"]
		var sc: float = l["scale"]
		var size := Kit.size(key) * sc
		var scroll: Vector2 = l["scroll"]
		# Wide enough to cover the whole walk across the house at the widest zoom.
		var span := world.x * scroll.x + 6000.0
		var top := centre_y * scroll.y - size.y * 0.5
		var tint: Color = l["tint"]
		var vertical := i > 0
		_drawer(0, func(n: Node2D) -> void:
			var t := Kit.tex(key)
			var rows := [0.0]
			if vertical:
				rows = [-2.0, -1.0, 0.0, 1.0, 2.0]
			for r: float in rows:
				n.draw_texture_rect_region(t, Rect2(-3000.0, top + r * size.y, span, size.y),
					Rect2(0, 0, span / sc, t.get_height()), tint)
		, p)
		i += 1


# ====================================================================== walls
func _build_walls() -> void:
	var rooms: Array = data["rooms"]
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		var mood: Dictionary = MOODS.get(r.get("mood", ""), {})
		var n := _drawer(-60, _draw_room.bind(r, mood, i))
		n.position = Vector2(r["x"], r["y"]) * TILE


func _draw_room(n: Node2D, r: Dictionary, mood: Dictionary, index: int) -> void:
	var size := Vector2(r["w"], r["h"]) * TILE
	var pad := TILE
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 7919 + 13
	var key: String = mood.get("wall", "")
	if key != "":
		var t := Kit.tex(key)
		var ts := t.get_size()
		# Fill the room's height, bottom aligned to its floor; a tall room
		# mirrors the texture upward. Never drawn beyond the room and its pad.
		var s := clampf((size.y + pad) / ts.y, 0.45, 1.0)
		var rect := Rect2(-pad, -pad, size.x + pad * 2.0, size.y + pad * 2.0)
		var ox := float(_hash(index, 3) % int(ts.x))
		n.draw_texture_rect_region(t, rect, Rect2(ox, ts.y - (size.y + pad) / s, rect.size.x / s, rect.size.y / s))
	# Depth: the top of every room falls away into shadow.
	var dark := Color(INK.r, INK.g, INK.b, 0.55)
	var clear := Color(INK.r, INK.g, INK.b, 0.0)
	n.draw_polygon(PackedVector2Array([Vector2(-pad, -pad), Vector2(size.x + pad, -pad), Vector2(size.x + pad, size.y * 0.42), Vector2(-pad, size.y * 0.42)]),
		PackedColorArray([dark, dark, clear, clear]))
	if key == "":
		return
	# Windows, where the wall is not covered by a painted plate.
	var win: String = mood.get("windows", "")
	if win != "":
		_draw_windows(n, r, size, win, index, rng)
	# Stains and cracks: a few, never in a row.
	var count := int(size.x / (TILE * 11.0))
	for k in count:
		var x := rng.randf_range(0.08, 0.92) * size.x
		if _covered(index, x + r["x"] * TILE, 90.0):
			continue
		var which := "decals/damp_stain" if rng.randf() < 0.55 else "decals/wall_crack"
		var h: float = HEIGHTS[which] * rng.randf_range(0.8, 1.1)
		var sz := Kit.size(which) * (h / Kit.size(which).y)
		var y := 0.0 if which == "decals/damp_stain" else rng.randf_range(0.25, 0.45) * size.y
		_put(n, which, Rect2(x - sz.x * 0.5, y, sz.x, sz.y), rng.randf() < 0.5, Color(1, 1, 1, 0.7))


func _draw_windows(n: Node2D, r: Dictionary, size: Vector2, win: String, index: int, rng: RandomNumberGenerator) -> void:
	var spacing := 8.0 * TILE
	var count := maxi(int(size.x / spacing), 1)
	for i in count:
		var cx := (i + 0.5) * size.x / count
		if _covered(index, cx + r["x"] * TILE, 110.0):
			continue
		var key := "arch/" + win
		var h: float
		var base: float
		match win:
			"lancet":
				var roll := rng.randf()
				key = "arch/lancet" if roll < 0.45 else ("arch/lancet_broken" if roll < 0.7 else ("arch/lancet_boarded" if roll < 0.85 else "arch/lancet_small"))
				h = minf(size.y * 0.66, 6.2 * TILE)
				base = size.y - 1.0 * TILE
			"cellar_bars":
				h = 1.9 * TILE
				base = 2.6 * TILE
			"dormer":
				h = minf(size.y * 0.72, 3.2 * TILE)
				base = size.y - 0.5 * TILE
			"porthole":
				h = 2.3 * TILE
				base = size.y * 0.62
			_:
				h = 3.0 * TILE
				base = size.y - TILE
		_stand(n, key, Vector2(cx, base), h, rng.randf() < 0.5)


func _covered(room: int, x: float, margin: float) -> bool:
	for s: Vector2 in _plate_spans.get(room, []):
		if x > s.x - margin and x < s.y + margin:
			return true
	return false


# ===================================================================== plates
func _build_plates() -> void:
	var holder := _drawer(-50, func(_n: Node2D) -> void: pass)
	for p: Dictionary in data.get("props", []):
		if p["sprite"] != "plate":
			continue
		var key: String = "plates/" + String(p["key"])
		var t := Kit.tex(key)
		if t == null:
			continue
		var m := Kit.meta(key)
		var s: float = float(p["width"]) * TILE / t.get_width()
		var size := t.get_size() * s
		var floor_y: float = float(p["y"]) * TILE
		var origin := Vector2(float(p["x"]) * TILE, floor_y - float(m["floor"]) * s - 2.0)
		var flip: bool = p.get("flip", false)
		var sprite := Sprite2D.new()
		sprite.texture = t
		sprite.centered = false
		sprite.position = origin + (Vector2(size.x, 0) if flip else Vector2.ZERO)
		sprite.scale = Vector2(-s if flip else s, s)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		holder.add_child(sprite)
		var room := room_index(int(p["x"] + 1.0), int(p["y"]) - 1)
		if not _plate_spans.has(room):
			_plate_spans[room] = []
		_plate_spans[room].append(Vector2(origin.x, origin.x + size.x))
		# Live flames over the painted ones.
		var pts: Array = []
		for w: Array in m.get("wicks", []):
			var local := Vector2(w[0], w[1]) * s
			if flip:
				local.x = size.x - local.x
			pts.append([origin + local, maxf(float(w[2]) * s * 0.8, 7.0)])
		_add_flames(pts, -49, true)


# ====================================================================== piers
func _build_piers() -> void:
	_drawer(-45, _draw_piers)


func _draw_piers(n: Node2D) -> void:
	var ramps: Array = []
	for s: Dictionary in data["slopes"]:
		var l: Array = s["line"]
		ramps.append(Vector2(minf(l[0], l[2]) - 1.0, maxf(l[0], l[2]) + 1.0))
	for r: Dictionary in data["rooms"]:
		if not r.get("mood", "") in ["grand_hall", "undercroft", "hall_upper", "library", "tower"]:
			continue
		var x := int(r["x"]) + 5
		while x < int(r["x"] + r["w"]) - 3:
			var blocked := false
			for rr: Vector2 in ramps:
				if x + 1 > rr.x and x < rr.y:
					blocked = true
			var y := int(r["y"] + r["h"])
			while not blocked and y > int(r["y"]):
				if solid(x, y) and solid(x + 1, y) and not solid(x, y - 1) and not solid(x + 1, y - 1):
					var top := y - 1
					while top > int(r["y"]) - 1 and not solid(x, top) and not solid(x + 1, top):
						top -= 1
					if y - top - 1 >= 5 and not _covered(room_index(x, y - 1), (x + 1) * TILE, 70.0):
						_column(n, (x + 1) * TILE, y * TILE, (top + 1) * TILE, _hash(x, y) % 5 == 0)
					y = top
				else:
					y -= 1
			x += 9


## A column three-sliced so its capital and base keep their shape at any height.
func _column(n: Node2D, cx: float, base: float, top: float, broken: bool) -> void:
	var key := "arch/column_broken" if broken else "arch/column"
	var t := Kit.tex(key)
	var ts := t.get_size()
	var w := 54.0
	var s := w / ts.x
	if broken:
		_put(n, key, Rect2(cx - w * 0.5, base - ts.y * s, w, ts.y * s), false, Color(0.8, 0.8, 0.9))
		return
	var cap := ts.y * 0.16
	var foot := ts.y * 0.14
	var h := base - top
	var tint := Color(0.8, 0.8, 0.9)
	n.draw_texture_rect_region(t, Rect2(cx - w * 0.5, top, w, cap * s), Rect2(0, 0, ts.x, cap), tint)
	n.draw_texture_rect_region(t, Rect2(cx - w * 0.5, top + cap * s, w, h - (cap + foot) * s), Rect2(0, cap, ts.x, ts.y - cap - foot), tint)
	n.draw_texture_rect_region(t, Rect2(cx - w * 0.5, base - foot * s, w, foot * s), Rect2(0, ts.y - foot, ts.x, foot), tint)


# ===================================================================== lights
func _build_lights() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var holder := _drawer(-28, func(_n: Node2D) -> void: pass)
	var i := 0
	for p: Dictionary in data.get("props", []):
		var kind: String = p["sprite"]
		if kind != "candle" and kind != "lamp":
			continue
		var at := Vector2(p["x"], p["y"]) * TILE
		var key: String
		var h: float
		var foot := at
		if kind == "lamp":
			key = "lights/father_lamp"
			h = HEIGHTS[key]
			foot = at + Vector2(0, -2.6 * TILE)
		else:
			var big := room_index(int(p["x"]), int(p["y"]) - 1) >= 0 and String(data["rooms"][room_index(int(p["x"]), int(p["y"]) - 1)].get("mood", "")) in ["grand_hall", "library", "dining", "living"]
			key = "lights/candelabrum_5" if big and i % 2 == 0 else ("lights/candle_table" if i % 5 == 3 else "lights/candelabrum_3")
			h = HEIGHTS[key]
		var s := h / Kit.size(key).y
		var size := Kit.size(key) * s
		var origin := foot - Vector2(size.x * 0.5, size.y)
		var spr := Sprite2D.new()
		spr.texture = Kit.tex(key)
		spr.centered = false
		spr.position = origin
		spr.scale = Vector2(s, s)
		spr.flip_h = i % 2 == 1
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		holder.add_child(spr)
		var pts: Array = []
		for w: Array in Kit.meta(key).get("wicks", []):
			var local := Vector2(w[0], w[1]) * s
			if spr.flip_h:
				local.x = size.x - local.x
			pts.append([origin + local, maxf(float(w[2]) * s * 1.1, 6.0)])
		var warm := kind == "candle"
		if warm:
			_add_flames(pts, -27, false)
		var centre := origin + Vector2(size.x * 0.5, size.y * (0.12 if warm else 0.55))
		for big_glow: bool in [true, false]:
			var g := Sprite2D.new()
			g.texture = _glow_tex
			g.material = add
			g.position = centre
			g.z_index = -26
			if warm:
				g.modulate = Color(1.0, 0.5, 0.58, 0.26) if big_glow else Color(1.0, 0.82, 0.7, 0.42)
			else:
				g.modulate = Color(0.4, 0.85, 1.0, 0.2) if big_glow else Color(0.7, 0.95, 1.0, 0.45)
			add_child(g)
			_lights.append({"node": g, "base": (6.5 if big_glow else 0.9), "ph": at.x * 0.013 + (0.0 if big_glow else 2.0),
				"a": g.modulate.a, "steady": not warm})
		i += 1


## A node that draws the flame loop at each point. pts: [[Vector2 base, height]]
func _add_flames(pts: Array, z: int, glow: bool) -> void:
	if pts.is_empty():
		return
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var ph := randi() % Kit.FLAME_LOOP
	var n := _drawer(z, func(node: Node2D) -> void:
		var k := 0
		for p: Array in pts:
			Kit.draw_flame(node, p[0], p[1], _ticks + ph + k * 13)
			k += 1
	, self, CanvasItem.TEXTURE_REPEAT_DISABLED)
	_flames.append(n)
	if glow:
		for p: Array in pts:
			var g := Sprite2D.new()
			g.texture = _glow_tex
			g.material = add
			g.position = (p[0] as Vector2) + Vector2(0, -float(p[1]) * 0.5)
			g.z_index = z + 1
			g.modulate = Color(1.0, 0.55, 0.6, 0.22)
			add_child(g)
			_lights.append({"node": g, "base": maxf(float(p[1]) / 12.0, 1.4), "ph": g.position.x * 0.01, "a": 0.22, "steady": false})


# ======================================================================= mass
func _build_mass() -> void:
	_drawer(0, _draw_mass)
	_drawer(-5, _draw_rails)
	_drawer(1, _draw_vaults)


func _draw_mass(n: Node2D) -> void:
	# The ink, bled past the level's edge so the camera never finds the end of
	# the earth. Dressed masses are inset a little: the wreckage drawn over
	# them is their edge, and the ink behind its gaps says "solid".
	var bleed := 40.0 * TILE
	var world := Vector2(_w, _h) * TILE
	n.draw_rect(Rect2(-bleed, -bleed, bleed, world.y + bleed * 2.0), INK)
	n.draw_rect(Rect2(world.x, -bleed, bleed, world.y + bleed * 2.0), INK)
	n.draw_rect(Rect2(0, -bleed, world.x, bleed), INK)
	n.draw_rect(Rect2(0, world.y, world.x, bleed), INK)
	for y in _h:
		var x := 0
		while x < _w:
			if solid(x, y) and not dressed(x, y):
				var x0 := x
				while x < _w and solid(x, y) and not dressed(x, y):
					x += 1
				n.draw_rect(Rect2(x0 * TILE - 1, y * TILE - 1, (x - x0) * TILE + 2, TILE + 2), INK)
			else:
				x += 1
	for p: Dictionary in data.get("props", []):
		if p["sprite"] == "wreck":
			var m: Array = p["mass"]
			# Ink only in the lower body of the mass, where gaps in the art
			# (under a table, between barrels) must still read as solid.
			var r := Rect2(Vector2(m[0], m[1]) * TILE, Vector2(m[2], m[3]) * TILE)
			r = r.grow_individual(-r.size.x * 0.2, -r.size.y * 0.4, -r.size.x * 0.2, 0)
			n.draw_rect(r, Color(INK.r, INK.g, INK.b, 0.9))
	# Packed earth: the mass's own texture, faint.
	var earth := Kit.tex("parallax/packed_earth")
	if earth != null:
		for r: Array in data["solids"]:
			var rect := Rect2(Vector2(r[0], r[1]) * TILE, Vector2(r[2], r[3]) * TILE)
			n.draw_texture_rect_region(earth, rect, Rect2(rect.position * 0.8, rect.size * 0.8), Color(1.9, 1.9, 2.1, 0.5))
	_draw_walls_faces(n)
	_draw_ceilings(n)
	_draw_floors(n)
	_draw_stairs(n)
	for o: Dictionary in data["oneways"]:
		_draw_oneway(n, o)


func _draw_floors(n: Node2D) -> void:
	for y in range(1, _h):
		var x := 0
		while x < _w:
			# A floor runs on under wreckage too: the art stands on it.
			if solid(x, y) and (not solid(x, y - 1) or dressed(x, y - 1)) and not dressed(x, y):
				var x0 := x
				while x < _w and solid(x, y) and (not solid(x, y - 1) or dressed(x, y - 1)) and not dressed(x, y):
					x += 1
				_floor_run(n, x0, x, y)
			else:
				x += 1


func _floor_run(n: Node2D, x0: int, x1: int, y: int) -> void:
	var mid := (x0 + x1) / 2
	var mood := mood_at(mid, y - 1)
	var variant: String = mood["floor"]
	if is_gallery(mid, y) and variant != "iron":
		variant = "gallery"
	var key := "edges/floor_" + variant
	var t := Kit.tex(key)
	var walk: float = Kit.meta(key)["walk"]
	var rect := Rect2(x0 * TILE, y * TILE - walk, (x1 - x0) * TILE, t.get_height())
	n.draw_texture_rect_region(t, rect, Rect2(_hash(x0, y) % t.get_width(), 0, rect.size.x, t.get_height()))
	if x1 - x0 < 4:
		return
	# Ends: a ledge's lip where the floor drops away, a corner where it meets a wall.
	var roots := _hash(x0, y * 3) % 3 == 0
	if solid(x0 - 1, y - 1) and solid(x0 - 1, y - 2) and not dressed(x0 - 1, y - 1):
		_corner(n, "edges/inner_corner_L", Vector2(x0 * TILE, y * TILE))
	elif not solid(x0 - 1, y):
		_corner(n, "edges/ledge_roots_L" if roots else "edges/ledge_end_L", Vector2(x0 * TILE, y * TILE))
	if solid(x1, y - 1) and solid(x1, y - 2) and not dressed(x1, y - 1):
		_corner(n, "edges/inner_corner_R", Vector2(x1 * TILE, y * TILE))
	elif not solid(x1, y):
		_corner(n, "edges/ledge_roots_R" if roots else "edges/ledge_end_R", Vector2(x1 * TILE, y * TILE))


func _corner(n: Node2D, key: String, at: Vector2) -> void:
	var m := Kit.meta(key)
	var off := Vector2(m["edge"], m.get("walk", m.get("soffit", 0)))
	_put(n, key, Rect2(at - off, Kit.size(key)))


func _draw_ceilings(n: Node2D) -> void:
	for y in range(0, _h - 1):
		var x := 0
		while x < _w:
			if solid(x, y) and not solid(x, y + 1) and not dressed(x, y):
				var x0 := x
				while x < _w and solid(x, y) and not solid(x, y + 1) and not dressed(x, y):
					x += 1
				_ceiling_run(n, x0, x, y + 1)
			else:
				x += 1


func _ceiling_run(n: Node2D, x0: int, x1: int, y: int) -> void:
	var mid := (x0 + x1) / 2
	var key: String = "edges/ceiling_" + String(mood_at(mid, y)["ceiling"])
	var t := Kit.tex(key)
	# Nothing may hang lower than CLEAR above the floor under it; cut the run
	# into stretches of equal clearance so a low doorway never gets long drips.
	var x := x0
	while x < x1:
		var c := clearance(x, y)
		var xe := x + 1
		while xe < x1 and clearance(xe, y) == c:
			xe += 1
		var hang := minf(t.get_height(), c * TILE - CLEAR)
		if hang > 10.0:
			var rect := Rect2(x * TILE, y * TILE - 2.0, (xe - x) * TILE, hang)
			n.draw_texture_rect_region(t, rect, Rect2((_hash(x0, y) + (x - x0) * int(TILE)) % t.get_width(), 0, rect.size.x, hang))
		x = xe
	if x1 - x0 < 4:
		return
	# The end of an overhang gets a moss-hung corner.
	for side: int in [-1, 1]:
		var ex := x0 - 1 if side < 0 else x1
		if not solid(ex, y - 1) and clearance(ex if side > 0 else x0, y) * TILE - CLEAR > 60.0:
			var ck := "edges/soffit_end_L" if side < 0 else "edges/soffit_end_R"
			_corner(n, ck, Vector2((x0 if side < 0 else x1) * TILE, y * TILE))


func _draw_walls_faces(n: Node2D) -> void:
	for x in range(1, _w):
		var y := 0
		while y < _h:
			var open_right := solid(x - 1, y) and not solid(x, y) and not dressed(x - 1, y)
			var open_left := solid(x, y) and not solid(x - 1, y) and not dressed(x, y)
			if open_right or open_left:
				var y0 := y
				while y < _h and ((open_right and solid(x - 1, y) and not solid(x, y) and not dressed(x - 1, y)) \
						or (open_left and solid(x, y) and not solid(x - 1, y) and not dressed(x, y))):
					y += 1
				if y - y0 >= 2:
					_wall_run(n, x, y0, y, open_right)
			else:
				y += 1


func _wall_run(n: Node2D, x: int, y0: int, y1: int, open_right: bool) -> void:
	var side := x if open_right else x - 1
	var mood := mood_at(side, (y0 + y1) / 2)
	var key: String = "edges/face_%s_%s" % [mood["face"], "R" if open_right else "L"]
	var t := Kit.tex(key)
	var face: float = Kit.meta(key)["face"]
	var inset := 8.0
	var left := x * TILE - face - inset if open_right else x * TILE - face + inset
	var rect := Rect2(left, y0 * TILE, t.get_width(), (y1 - y0) * TILE)
	n.draw_texture_rect_region(t, rect, Rect2(0, _hash(x, y0) % t.get_height(), t.get_width(), rect.size.y))


func _draw_stairs(n: Node2D) -> void:
	var slopes: Array = data["slopes"]
	for s: Dictionary in slopes:
		var poly := PackedVector2Array()
		for p: Array in s["pts"]:
			poly.append(Vector2(p[0], p[1]) * TILE)
		n.draw_colored_polygon(poly, INK)
	for s: Dictionary in slopes:
		var note: String = s.get("note", "")
		var l: Array = s["line"]
		var a := Vector2(l[0], l[1]) * TILE
		var b := Vector2(l[2], l[3]) * TILE
		if a.x > b.x:
			var tmp := a
			a = b
			b = tmp
		var rising := b.y < a.y
		var thick: Variant = s.get("thick")
		var key: String
		var rect: Rect2
		if note.begins_with("fallen flight, down"):
			continue
		if note.begins_with("fallen flight, up"):
			# Both halves of the fallen flight are one mound of steps.
			var other: Dictionary = {}
			for o: Dictionary in slopes:
				if String(o.get("note", "")).begins_with("fallen flight, down"):
					other = o
			var end_x: float = maxf(other["line"][0], other["line"][2]) * TILE
			key = "arch/stair_mound"
			rect = Rect2(a.x, minf(a.y, b.y), end_x - a.x, maxf(a.y, b.y) - minf(a.y, b.y))
			_put(n, key, rect.grow_individual(0, 6, 0, 2))
			continue
		var top := minf(a.y, b.y)
		if thick == null:
			var steep := absf(b.y - a.y) / maxf(b.x - a.x, 1.0) > 0.75
			key = ("arch/stair_steep_up" if rising else "arch/stair_steep_down_rubble") if steep else ("arch/stair_up" if rising else "arch/stair_down")
			rect = Rect2(a.x, top, b.x - a.x, maxf(a.y, b.y) - top)
			_put(n, key, rect.grow_individual(0, 6, 0, 2))
		else:
			key = "arch/stair_broken_up" if note.contains("remnant") else "arch/stair_flying_up"
			rect = Rect2(a.x, top, b.x - a.x, absf(b.y - a.y) + float(thick) * TILE)
			# flying pieces rise to the right; a remnant's broken end is its free (high) end
			var flip := not rising
			if note.contains("remnant"):
				flip = rising
			_put(n, key, rect.grow_individual(0, 6, 0, 0), flip)


func _draw_oneway(n: Node2D, o: Dictionary) -> void:
	var x0: float = o["x"] * TILE
	var y0: float = o["y"] * TILE
	var ow: float = o["w"] * TILE
	var key := "machines/lamp_platform" if o.get("kind", "") == "lamp" else "machines/pipe_platform"
	var t := Kit.tex(key)
	var s := ow / t.get_width()
	var deck: float = Kit.meta(key)["deck"]
	_put(n, key, Rect2(x0, y0 - deck * s, ow, t.get_height() * s))
	if o.get("kind", "") == "lamp":
		var chain := Kit.tex("machines/chain")
		var cs := 0.55
		for cx: float in [x0 + ow * 0.18, x0 + ow * 0.82]:
			var r := Rect2(cx - chain.get_width() * cs * 0.5, y0 - 640.0, chain.get_width() * cs, 640.0 - deck * s + 6.0)
			n.draw_texture_rect_region(chain, r, Rect2(0, 0, chain.get_width(), r.size.y / cs))


func _draw_rails(n: Node2D) -> void:
	# Iron railings: along every stair's tread line and every gallery's edge.
	var t := Kit.tex("arch/rail_section")
	var hgt := 86.0
	var s := hgt / t.get_height()
	for sl: Dictionary in data["slopes"]:
		var l: Array = sl["line"]
		var a := Vector2(l[0], l[1]) * TILE
		var b := Vector2(l[2], l[3]) * TILE
		if a.x > b.x:
			var tmp := a
			a = b
			b = tmp
		var slope := (b.y - a.y) / maxf(b.x - a.x, 1.0)
		# Skew, so the balusters stay upright while the rail follows the stair.
		n.draw_set_transform_matrix(Transform2D(Vector2(1, slope), Vector2(0, 1), a + Vector2(0, -hgt + 4.0)))
		n.draw_texture_rect_region(t, Rect2(0, 0, b.x - a.x, hgt), Rect2(0, 0, (b.x - a.x) / s, t.get_height()))
		n.draw_set_transform_matrix(Transform2D.IDENTITY)
	var newel := Kit.tex("arch/rail_newel")
	var ns := (hgt + 34.0) / newel.get_height()
	for y in range(2, _h - 3):
		var x := 0
		while x < _w:
			var gallery := solid(x, y) and not solid(x, y - 1) and not solid(x, y - 2) and not dressed(x, y) \
				and is_gallery(x, y)
			if gallery:
				var x0 := x
				while x < _w and solid(x, y) and not solid(x, y - 1) and not dressed(x, y) and is_gallery(x, y):
					x += 1
				if x - x0 >= 4:
					var a := Vector2(x0 * TILE + 10.0, y * TILE)
					var w := (x - x0) * TILE - 20.0
					n.draw_texture_rect_region(t, Rect2(a.x, a.y - hgt + 4.0, w, hgt), Rect2(_hash(x0, y) % t.get_width(), 0, w / s, t.get_height()))
					for px: float in [a.x, a.x + w]:
						n.draw_texture_rect(newel, Rect2(px - newel.get_width() * ns * 0.5, a.y - newel.get_height() * ns + 4.0, newel.get_width() * ns, newel.get_height() * ns), false)
			else:
				x += 1


func _draw_vaults(n: Node2D) -> void:
	# Gothic shoulders in each room's upper corners and a boss under each bay.
	for r: Dictionary in data["rooms"]:
		var rx := int(r["x"])
		var ry := int(r["y"])
		var rw := int(r["w"])
		var rh := int(r["h"])
		var tall := rh >= 12
		var reach := minf((rh - 2.5) * TILE - COWL_H, (3.4 if tall else 2.2) * TILE)
		if reach > 70.0 and rw >= 6:
			for side: int in [-1, 1]:
				var wall_x := rx - 1 if side < 0 else rx + rw
				var inner_x := rx if side < 0 else rx + rw - 1
				var ok := solid(wall_x, ry) and solid(wall_x, ry + 1) and solid(wall_x, ry + 2) and solid(inner_x, ry - 1)
				for j in 4:
					if solid(inner_x, ry + j) or solid(inner_x - side, ry + j):
						ok = false
				if not ok:
					continue
				var key := ("arch/spandrel_tall_" if tall else "arch/spandrel_") + ("L" if side < 0 else "R")
				var t := Kit.tex(key)
				var s := reach / t.get_height()
				var size := t.get_size() * s
				var x := rx * TILE - 6.0 if side < 0 else (rx + rw) * TILE - size.x + 6.0
				_put(n, key, Rect2(x, ry * TILE - 4.0, size.x, size.y))
		if rw >= 18 and rh >= 8:
			var bays := int(round(rw / 11.0))
			for b in range(1, bays):
				var bx := rx + int(round(float(rw) * b / bays))
				var clear := true
				for i in range(-2, 2):
					if not solid(bx + i, ry - 1):
						clear = false
					for j in 6:
						if solid(bx + i, ry + j):
							clear = false
				if clear:
					_stand(n, "arch/corbel_bat", Vector2(bx * TILE, ry * TILE + 92.0), 92.0)


# =================================================================== wreckage
func _build_wreckage() -> void:
	_drawer(1, func(n: Node2D) -> void:
		for p: Dictionary in data.get("props", []):
			if p["sprite"] != "wreck":
				continue
			var r: Array = p["rect"]
			_put(n, "wreck/" + String(p["key"]), Rect2(Vector2(r[0], r[1]) * TILE, Vector2(r[2], r[3]) * TILE), p.get("flip", false))
		# Floor litter by the wreckage: books in the library, glass under
		# windows, rubble elsewhere. Capped to a quarter tile tall.
		for p: Dictionary in data.get("props", []):
			if p["sprite"] != "wreck":
				continue
			var m: Array = p["mass"]
			var y: float = (m[1] + m[3]) * TILE
			var mood := String(data["rooms"][maxi(room_index(int(m[0]), int(m[1] + m[3]) - 1), 0)].get("mood", ""))
			var key := "decals/fallen_books" if mood in ["library", "study", "living"] else ("decals/broken_glass" if mood in ["conservatory", "attic"] else "decals/rubble")
			var size := Kit.size(key)
			var s := minf(FLOOR_DECAL_MAX / size.y, 1.4 * TILE / size.x)
			var side := 1.0 if _hash(int(m[0]), 9) % 2 == 0 else -1.0
			var cx: float = (m[0] + (m[2] + 0.9 if side > 0 else -0.9)) * TILE
			if not solid(int(cx / TILE), int(y / TILE)) or solid(int(cx / TILE), int(y / TILE) - 1):
				continue
			_put(n, key, Rect2(cx - size.x * s * 0.5, y - size.y * s + 2.0, size.x * s, size.y * s), side < 0)
	)


# ===================================================================== frames
func _build_frames() -> void:
	_drawer(2, func(n: Node2D) -> void:
		for p: Dictionary in data.get("props", []):
			if p["sprite"] != "frame":
				continue
			var x: float = p["x"]
			var floor_y: float = p["y"]
			var w: float = p.get("w", 2)
			var h: float = p.get("h", 4)
			var mood := String(data["rooms"][maxi(room_index(int(x) - 1, int(floor_y) - 1), 0)].get("mood", ""))
			var roll := _hash(int(x), int(floor_y)) % 7
			var key := "arch/door_gothic"
			if mood in ["pantry", "storage", "workshop", "boiler", "undercroft", "lab"]:
				key = "arch/door_round"
			elif roll == 0:
				key = "arch/door_broken"
			elif roll == 1:
				key = "arch/door_narrow_roots"
			elif roll == 2 or h >= 6:
				key = "arch/door_tall"
			var size := Kit.size(key)
			var height := (h + 1.3) * TILE
			var s := height / size.y
			# The frame's opening must not look narrower than the doorway.
			s = maxf(s, (w + 1.1) * TILE / size.x)
			var fs := size * s
			_put(n, key, Rect2((x + w * 0.5) * TILE - fs.x * 0.5, floor_y * TILE - fs.y + 4.0, fs.x, fs.y))
	)


# ======================================================================= moss
func _build_moss() -> void:
	var still := _drawer(20, _draw_moss)
	still.modulate = Color(0.85, 0.85, 0.92)
	# Swaying strands in the tall open rooms, where they have room to hang.
	_sway_node = _drawer(20, _draw_sway)
	_sway_node.modulate = Color(0.85, 0.85, 0.92)
	for y in range(0, _h - 1):
		var x := 0
		while x < _w:
			if solid(x, y) and not solid(x, y + 1) and clearance(x, y + 1) >= 9:
				if _hash(x, y) % 23 == 0:
					_sways.append({"pos": Vector2(x * TILE + 32.0, (y + 1) * TILE - 4.0), "ph": _hash(x, y) % 64,
						"flip": _hash(y, x) % 2 == 0, "h": minf(280.0, (clearance(x, y + 1) * TILE - CLEAR) * 0.8)})
			x += 1


func _draw_moss(n: Node2D) -> void:
	for y in range(0, _h - 1):
		var x := 0
		while x < _w:
			if solid(x, y) and not solid(x, y + 1) and not dressed(x, y):
				var room := clearance(x, y + 1) * TILE - CLEAR
				var roll := _hash(x * 7, y * 13) % 100
				if room > 30.0 and roll < 16:
					var i := _hash(x, y * 5) % 8
					var key := "moss/clump_%d" % i
					var size := Kit.size(key)
					var s: float = float(MOSS_W[i]) / size.x
					s = minf(s, room / size.y)
					_put(n, key, Rect2(x * TILE + 32.0 - size.x * s * 0.5, (y + 1) * TILE - 6.0, size.x * s, size.y * s), roll % 2 == 0)
					x += 2
			x += 1


func _draw_sway(n: Node2D) -> void:
	for s: Dictionary in _sways:
		var frame := int((_ticks + int(s["ph"])) / Kit.SWAY_TICKS) % 8
		var key := "sway/f%d" % frame
		var t := Kit.tex(key)
		if t == null:
			continue
		var anchor: Array = Kit.meta(key)["anchor"]
		var sc: float = float(s["h"]) / t.get_height()
		var pos: Vector2 = s["pos"]
		var rect := Rect2(pos - Vector2(anchor[0], anchor[1]) * sc, t.get_size() * sc)
		_put(n, key, rect, s["flip"])


# ==================================================================== overlay
func _build_overlay() -> void:
	_dust = CPUParticles2D.new()
	_dust.amount = 70
	_dust.lifetime = 9.0
	_dust.preprocess = 9.0
	_dust.local_coords = false
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(1500, 850)
	_dust.direction = Vector2(1, -0.3)
	_dust.spread = 180.0
	_dust.gravity = Vector2(4, -3)
	_dust.initial_velocity_min = 4.0
	_dust.initial_velocity_max = 16.0
	_dust.scale_amount_min = 1.5
	_dust.scale_amount_max = 4.0
	_dust.color = Color(0.75, 0.72, 1.0, 0.24)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_dust.color_ramp = ramp
	_dust.z_index = 25
	add_child(_dust)

	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "
shader_type canvas_item;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p * vec2(1.0, 0.82));
	float v = smoothstep(0.4, 0.88, d);
	COLOR = vec4(0.015, 0.01, 0.04, v * 0.72);
}"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	layer.add_child(rect)


func _process(delta: float) -> void:
	_t += delta
	_ticks = int(_t * 60.0)
	var cam := get_viewport().get_camera_2d()
	if cam != null and _dust != null:
		_dust.global_position = cam.get_screen_center_position()
	for c: Dictionary in _lights:
		var g: Sprite2D = c["node"]
		var ph: float = c["ph"]
		var f := 1.0 + sin(_t * 9.0 + ph) * 0.05 + sin(_t * 17.3 + ph * 2.1) * 0.035 + sin(_t * 2.1 + ph) * 0.04
		if c.get("steady", false):
			f = 1.0 + sin(_t * 1.3 + ph) * 0.03
		var base: float = c["base"]
		g.scale = Vector2(base, base) * f
		g.modulate.a = float(c["a"]) * (0.9 + (f - 1.0) * 2.0)
	for f: Node2D in _flames:
		f.queue_redraw()
	if _sway_node != null and not _sways.is_empty() and _ticks % Kit.SWAY_TICKS == 0:
		_sway_node.queue_redraw()
