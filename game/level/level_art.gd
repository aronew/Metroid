extends Node2D
## The art pass, kept deliberately plain: the collision mass in black, its
## edges dressed with the kit's floor tops, ceilings, wall faces and corners,
## the staircases, and the parallax arcades behind. Nothing else: no painted
## rooms, no wreckage, no props. It never collides, and it never adds a shape
## the collision does not have.
##
## Layers, far to near (z_index):
##   screen  haze gradient
##   para    far arcades, middle galleries, near arcade   (kit W03-W05)
##     0     the mass in black, then floor tops (W08), ceilings (W09),
##           wall faces (W10), corners (W11), stairs (W13), ledges
##   screen  vignette
##
## F6 switches the edge dressing off, leaving the black blocks alone.

const TILE := 64.0
const INK := Color("040409")         # the mass: black, with a breath of the kit's indigo
## Nothing hangs lower than this above the floor beneath it.
const CLEAR := 2.5 * TILE
## Floor, ceiling and wall pieces by room mood.
const MOODS := {
	"bedroom": {"floor": "carved", "ceiling": "ribs", "face": "pilaster"},
	"hall_upper": {"floor": "carved", "ceiling": "ribs", "face": "pilaster"},
	"kitchen": {"floor": "flagstone", "ceiling": "beams", "face": "pilaster"},
	"dining": {"floor": "carved", "ceiling": "ribs", "face": "pilaster"},
	"living": {"floor": "carved", "ceiling": "ribs", "face": "pilaster"},
	"study": {"floor": "carved", "ceiling": "beams", "face": "pilaster"},
	"library": {"floor": "carved", "ceiling": "ribs", "face": "pilaster"},
	"attic": {"floor": "carved", "ceiling": "beams", "face": "stone"},
	"pantry": {"floor": "flagstone", "ceiling": "stone", "face": "stone"},
	"storage": {"floor": "flagstone", "ceiling": "stone", "face": "stone"},
	"workshop": {"floor": "flagstone", "ceiling": "iron", "face": "stone"},
	"boiler": {"floor": "flagstone", "ceiling": "iron", "face": "stone"},
	"lab": {"floor": "iron", "ceiling": "iron", "face": "stone"},
	"conservatory": {"floor": "flagstone", "ceiling": "stone", "face": "stone"},
	"tower": {"floor": "flagstone", "ceiling": "stone", "face": "stone"},
	"grand_hall": {"floor": "carved", "ceiling": "ribs", "face": "pilaster"},
	"undercroft": {"floor": "flagstone", "ceiling": "stone", "face": "stone"},
}

var level: Level
var data: Dictionary
var _w := 0
var _h := 0
var _solid: PackedByteArray
var _room_of: PackedInt32Array       # room index per cell (-1 outside)
var _edges: Node2D


func dress(lvl: Level) -> void:
	level = lvl
	data = lvl.data
	_w = int(data["w"])
	_h = int(data["h"])
	_build_grids()
	_build_sky()
	_build_parallax()
	_drawer(0, _draw_blocks)
	_edges = _drawer(1, _draw_edges)
	_build_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_F6:
		_edges.visible = not _edges.visible


# ====================================================================== grids
func _build_grids() -> void:
	_solid = PackedByteArray()
	_solid.resize(_w * _h)
	_room_of = PackedInt32Array()
	_room_of.resize(_w * _h)
	_room_of.fill(-1)
	for r: Array in data["solids"]:
		for y in range(int(r[1]), int(r[1] + r[3])):
			for x in range(int(r[0]), int(r[0] + r[2])):
				_solid[y * _w + x] = 1
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


func dressed(_x: int, _y: int) -> bool:
	return false


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
		{"key": "parallax/middle_galleries", "scroll": Vector2(0.2, 0.1), "scale": 1.15, "tint": Color(0.88, 0.88, 1.0, 0.4)},
		# The near arcade has big black shapes; kept faint so nothing behind the
		# play can be mistaken for the black collision in front of it.
		{"key": "parallax/near_arcade", "scroll": Vector2(0.38, 0.2), "scale": 1.25, "tint": Color(0.85, 0.85, 1.0, 0.28)},
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


# ===================================================================== blocks
func _draw_blocks(n: Node2D) -> void:
	# The collision mass in black, bled past the level's edge so the camera
	# never finds the end of the earth. Ramps are part of the mass.
	var bleed := 40.0 * TILE
	var world := Vector2(_w, _h) * TILE
	n.draw_rect(Rect2(-bleed, -bleed, bleed, world.y + bleed * 2.0), INK)
	n.draw_rect(Rect2(world.x, -bleed, bleed, world.y + bleed * 2.0), INK)
	n.draw_rect(Rect2(0, -bleed, world.x, bleed), INK)
	n.draw_rect(Rect2(0, world.y, world.x, bleed), INK)
	for r: Array in data["solids"]:
		n.draw_rect(Rect2(Vector2(r[0], r[1]) * TILE - Vector2(1, 1), Vector2(r[2], r[3]) * TILE + Vector2(2, 2)), INK)
	for s: Dictionary in data["slopes"]:
		var poly := PackedVector2Array()
		for p: Array in s["pts"]:
			poly.append(Vector2(p[0], p[1]) * TILE)
		n.draw_colored_polygon(poly, INK)
	# Ledges: black bars at their collision line, so the blocks alone read.
	for o: Dictionary in data["oneways"]:
		n.draw_rect(Rect2(o["x"] * TILE, o["y"] * TILE, o["w"] * TILE, 16.0), INK)


# ====================================================================== edges
func _draw_edges(n: Node2D) -> void:
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
	# A ledge is a short floor: the gallery floor-top strip, its walking line
	# on the collision line, capped with the ledge-end lips.
	var key := "edges/floor_gallery"
	var t := Kit.tex(key)
	var walk: float = Kit.meta(key)["walk"]
	var x0: float = float(o["x"]) * TILE
	var y0: float = float(o["y"]) * TILE
	var w: float = float(o["w"]) * TILE
	var h := 44.0
	n.draw_texture_rect_region(t, Rect2(x0, y0 - walk * 0.55, w, h), Rect2(_hash(int(x0), int(y0)) % t.get_width(), 0, w / 0.55, h / 0.55))
	for side: int in [0, 1]:
		var ck := "edges/ledge_end_L" if side == 0 else "edges/ledge_end_R"
		var m := Kit.meta(ck)
		var s := 0.5
		var size := Kit.size(ck) * s
		var at := Vector2(x0 if side == 0 else x0 + w, y0)
		_put(n, ck, Rect2(at - Vector2(float(m["edge"]), float(m["walk"])) * s, size))


# ==================================================================== overlay
func _build_overlay() -> void:
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
	float v = smoothstep(0.42, 0.9, d);
	COLOR = vec4(0.0, 0.0, 0.02, v * 0.6);
}"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	layer.add_child(rect)
