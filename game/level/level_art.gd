extends Node2D
## The art pass: dresses a Level's data and never collides.
##
## The look follows the environment mockups: rooms are openings in solid
## black, their walls a hazy indigo, with a deep Gothic vista behind and
## everything close to the eye drawn as ink. Layers, far to near:
##
##   screen     haze gradient                           (fixed to the screen)
##   0.10-0.50  far arcades, mid arcades, near windows  (parallax)
##   1.0  -60   room walls, windows, shelves
##   1.0  -50   painted plates cut from the mockups (assets/plates)
##   1.0  -30   railings, balustrades, candle light
##   1.0    0   the collision mass in ink, its edges, vault ribs
##   1.0   10   Cowl and the creatures (set by their own scripts)
##   1.0   20   moss and roots hanging in front
##   screen     dust, vignette
##
## Everything here is derived from the level JSON: rooms and their `mood`,
## the solid rectangles, the ramps and the `props`. Art is laid along the
## collision's edges; it never adds a shape the collision does not have.

const TILE := 64.0
const TILT := 0.055          # the house leans: hanging things hang true, so they look askew

const MOODS := {
	"bedroom": {"wall": Color(0.235, 0.2, 0.4), "windows": true},
	"hall_upper": {"wall": Color(0.2, 0.18, 0.36), "windows": true},
	"kitchen": {"wall": Color(0.21, 0.19, 0.39), "windows": false},
	"dining": {"wall": Color(0.25, 0.22, 0.45), "windows": true},
	"living": {"wall": Color(0.26, 0.22, 0.44), "windows": false},
	"study": {"wall": Color(0.2, 0.18, 0.38), "shelves": true},
	"library": {"wall": Color(0.19, 0.17, 0.36), "shelves": true},
	"attic": {"wall": Color(0.1, 0.095, 0.2), "beams": true},
	"pantry": {"wall": Color(0.13, 0.13, 0.27), "courses": true},
	"storage": {"wall": Color(0.15, 0.14, 0.3), "courses": true},
	"workshop": {"wall": Color(0.13, 0.14, 0.28), "courses": true, "pipes": true},
	"boiler": {"wall": Color(0.16, 0.12, 0.25), "courses": true, "pipes": true},
	"lab": {"wall": Color(0.07, 0.15, 0.22), "panels": true},
	"conservatory": {"wall": Color(0.1, 0.2, 0.24), "glass": true},
	"tower": {"wall": Color(0.12, 0.12, 0.26), "windows": true, "alpha": 0.55},
	"grand_hall": {"open": true},
	"undercroft": {"open": true, "tint": Color(0.16, 0.2, 0.4)},
}

var level: Level
var data: Dictionary
var _w := 0
var _h := 0
var _solid: PackedByteArray
var _glow_tex: Texture2D
var _candles: Array = []
var _t := 0.0
var _dust: CPUParticles2D
var _plates_meta: Dictionary = {}


func dress(lvl: Level) -> void:
	level = lvl
	data = lvl.data
	_w = int(data["w"])
	_h = int(data["h"])
	_build_grid()
	_glow_tex = _make_glow()
	var meta_path := "res://assets/plates/plates.json"
	if FileAccess.file_exists(meta_path):
		_plates_meta = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
	_build_sky()
	_build_parallax()
	_build_rooms()
	_build_plates()
	_build_lights()
	_build_mass()
	_build_overlay()


# ======================================================================= grid
func _build_grid() -> void:
	_solid = PackedByteArray()
	_solid.resize(_w * _h)
	for r: Array in data["solids"]:
		for y in range(int(r[1]), int(r[1] + r[3])):
			for x in range(int(r[0]), int(r[0] + r[2])):
				_solid[y * _w + x] = 1


func solid(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return true
	return _solid[y * _w + x] == 1


func _open_run(x: int, y: int, dx: int, dy: int, n: int) -> bool:
	for i in n:
		if solid(x + dx * i, y + dy * i):
			return false
	return true


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


func _add_drawer(z: int, draw_fn: Callable, parent: Node = self) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	n.draw.connect(draw_fn.bind(n))
	parent.add_child(n)
	return n


# ======================================================================== sky
func _build_sky() -> void:
	# The haze the whole house hangs in: deep at the top, a band of lavender
	# light low in the frame, deep again beneath.
	var layer := CanvasLayer.new()
	layer.layer = -100
	add_child(layer)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.42, 0.68, 1.0])
	g.colors = PackedColorArray([Color("12112a"), Color("3b3a6e"), Color("5a5296"), Color("1a1936")])
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
	# Three depths of the same Gothic arcade, each paler and smaller than the
	# one in front: the tiers of galleries that fade into the haze in the mockups.
	var layers := [
		{"scroll": 0.1, "size": Vector2(1920, 760), "bay": 120.0, "band": Color("46437f"), "open": Color("57528f"), "alpha": 0.45},
		{"scroll": 0.24, "size": Vector2(2240, 1040), "bay": 224.0, "band": Color("37356b"), "open": Color("4a4680"), "alpha": 0.55},
		{"scroll": 0.46, "size": Vector2(2880, 1500), "bay": 480.0, "band": Color("262450"), "open": Color("37346a"), "alpha": 0.62},
	]
	var i := 0
	for l: Dictionary in layers:
		var p := Parallax2D.new()
		p.scroll_scale = Vector2(l["scroll"], l["scroll"])
		p.repeat_size = l["size"]
		p.repeat_times = 5
		p.z_index = -90 + i
		p.modulate.a = l["alpha"]
		add_child(p)
		_add_drawer(0, _draw_arcade.bind(l), p)
		i += 1


func _arch(cx: float, base: float, w: float, h: float, steps: int = 10) -> PackedVector2Array:
	## A pointed (two-centred) arch standing on `base`, as a closed polygon.
	var pts := PackedVector2Array()
	var spring := base - h * 0.45
	pts.append(Vector2(cx - w * 0.5, base))
	for k in steps + 1:
		var f := float(k) / steps
		# left haunch: from the springing up to the point
		var a := f * PI * 0.5
		pts.append(Vector2(cx - w * 0.5 + (1.0 - cos(a)) * w * 0.5, spring - sin(a) * h * 0.55))
	for k in range(steps - 1, -1, -1):
		var f := float(k) / steps
		var a := f * PI * 0.5
		pts.append(Vector2(cx + w * 0.5 - (1.0 - cos(a)) * w * 0.5, spring - sin(a) * h * 0.55))
	pts.append(Vector2(cx + w * 0.5, base))
	return pts


func _draw_arcade(n: Node2D, l: Dictionary) -> void:
	var size: Vector2 = l["size"]
	var bay: float = l["bay"]
	var band: Color = l["band"]
	var open: Color = l["open"]
	# Two tiers per tile: a tall arcade over a low one, with a balustrade between.
	var tiers := [[0.0, 0.6], [0.6, 0.4]]
	for t: Array in tiers:
		var top := size.y * float(t[0])
		var th := size.y * float(t[1])
		n.draw_rect(Rect2(0, top, size.x, th), band)
		var count := int(size.x / bay)
		for b in count:
			var cx := (b + 0.5) * bay
			n.draw_colored_polygon(_arch(cx, top + th * 0.93, bay * 0.72, th * 0.86), open)
			# mullion and a trefoil eye: enough tracery to read as a window
			n.draw_line(Vector2(cx, top + th * 0.93), Vector2(cx, top + th * 0.2), band, bay * 0.022)
			n.draw_line(Vector2(cx - bay * 0.36, top + th * 0.5), Vector2(cx + bay * 0.36, top + th * 0.5), band, bay * 0.016)
			# light gathers low in each opening, as it does in the mockups
			var glow := Color(open.r * 1.25, open.g * 1.2, open.b * 1.2, 0.5)
			n.draw_colored_polygon(_arch(cx, top + th * 0.93, bay * 0.5, th * 0.45), glow)
			# the pier between bays
			var px := b * bay
			n.draw_rect(Rect2(px - bay * 0.045, top + th * 0.1, bay * 0.09, th * 0.9), band.darkened(0.15))
			n.draw_rect(Rect2(px - bay * 0.08, top + th * 0.36, bay * 0.16, th * 0.03), band.darkened(0.15))
		# balustrade
		n.draw_rect(Rect2(0, top + th * 0.93, size.x, th * 0.07), band.darkened(0.25))
		var posts := int(size.x / (bay * 0.125))
		for k in posts:
			n.draw_rect(Rect2(k * bay * 0.125, top + th * 0.86, bay * 0.02, th * 0.07), band.darkened(0.25))
		n.draw_rect(Rect2(0, top + th * 0.855, size.x, th * 0.012), band.darkened(0.25))


# ====================================================================== rooms
func _build_rooms() -> void:
	for r: Dictionary in data["rooms"]:
		var mood: Dictionary = MOODS.get(r.get("mood", ""), {})
		if mood.is_empty():
			continue
		var n := _add_drawer(-60, _draw_room.bind(r, mood))
		n.position = Vector2(r["x"], r["y"]) * TILE


func _plates_in(r: Dictionary) -> Array:
	## Horizontal spans (in room-local px) already covered by a painted plate.
	var spans := []
	for p: Dictionary in data.get("props", []):
		var sprite: String = p["sprite"]
		if not sprite.begins_with("plate:"):
			continue
		var meta: Dictionary = _plates_meta.get(sprite.trim_prefix("plate:"), {})
		if meta.is_empty():
			continue
		var s := float(p.get("scale", 1.0))
		var x0: float = float(p["x"]) - float(r["x"])
		var wt: float = float(meta["size"][0]) * s / TILE
		if p["y"] > r["y"] and p["y"] <= r["y"] + r["h"] and x0 + wt > 0.0 and x0 < r["w"]:
			spans.append(Vector2(x0 * TILE, (x0 + wt) * TILE))
	return spans


func _draw_room(n: Node2D, r: Dictionary, mood: Dictionary) -> void:
	var size := Vector2(r["w"], r["h"]) * TILE
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r["x"]) * 131 + int(r["y"])
	if mood.get("open", false):
		if mood.has("tint"):
			var t: Color = mood["tint"]
			_grad_rect(n, Rect2(Vector2(-TILE, -TILE), size + Vector2(2, 2) * TILE), Color(t.r, t.g, t.b, 0.55), Color(t.r * 0.5, t.g * 0.5, t.b * 0.6, 0.75))
		return
	var wall: Color = mood["wall"]
	var alpha: float = mood.get("alpha", 0.86)
	# The wall: lit at mid-height, falling off to the ceiling and the skirting.
	var top_c := Color(wall.r * 0.55, wall.g * 0.55, wall.b * 0.62, alpha)
	var mid_c := Color(wall.r * 1.12, wall.g * 1.1, wall.b * 1.12, alpha)
	var bot_c := Color(wall.r * 0.7, wall.g * 0.68, wall.b * 0.76, alpha)
	var pad := TILE
	_grad_rect(n, Rect2(-pad, -pad, size.x + pad * 2.0, size.y * 0.55 + pad), top_c, mid_c)
	_grad_rect(n, Rect2(-pad, size.y * 0.55, size.x + pad * 2.0, size.y * 0.45 + pad), mid_c, bot_c)
	var covered := _plates_in(r)
	var line := Color(wall.r * 0.5, wall.g * 0.5, wall.b * 0.58, 0.9)

	if mood.get("windows", false):
		# Tall lancets with the lavender haze behind them.
		var spacing := 7.0 * TILE
		var count := int(size.x / spacing)
		for i in count:
			var cx := (i + 0.5) * size.x / count
			if _covered(covered, cx, 150.0):
				continue
			var wh := minf(size.y * 0.7, 7.0 * TILE)
			var base := size.y - 1.4 * TILE
			_window(n, cx, base, 2.4 * TILE, wh, wall)
	if mood.get("shelves", false):
		_shelves(n, size, covered, wall, rng)
	if mood.get("courses", false):
		# Cellar stone: courses and the odd upright joint.
		var y := 0.0
		while y < size.y:
			n.draw_line(Vector2(-pad, y), Vector2(size.x + pad, y), Color(line.r, line.g, line.b, 0.35), 2.0)
			var x := rng.randf_range(0.0, 120.0)
			while x < size.x:
				n.draw_line(Vector2(x, y), Vector2(x, y + 70.0), Color(line.r, line.g, line.b, 0.22), 2.0)
				x += rng.randf_range(110.0, 190.0)
			y += 70.0
	if mood.get("pipes", false):
		for i in 3:
			var y := size.y * (0.14 + 0.11 * i)
			n.draw_line(Vector2(-pad, y), Vector2(size.x + pad, y), Color(line.r, line.g, line.b, 0.85), 10.0 - i * 2.0)
			var x := rng.randf_range(100.0, 300.0)
			while x < size.x:
				n.draw_rect(Rect2(x, y - 9.0, 14.0, 18.0), line)
				x += rng.randf_range(260.0, 520.0)
	if mood.get("beams", false):
		# Roof timbers, raking.
		var x := -TILE
		while x < size.x + TILE:
			n.draw_line(Vector2(x, size.y), Vector2(x + size.y * 0.55, 0), Color(line.r, line.g, line.b, 0.7), 14.0)
			n.draw_line(Vector2(x + size.y * 1.1, size.y), Vector2(x + size.y * 0.55, 0), Color(line.r, line.g, line.b, 0.7), 14.0)
			x += size.y * 1.6
	if mood.get("panels", false):
		# Father's work: plate metal, seams, and a thin live line.
		var x := 0.0
		while x < size.x:
			n.draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.03, 0.07, 0.12, 0.7), 4.0)
			x += 3.0 * TILE
		n.draw_line(Vector2(-pad, size.y * 0.42), Vector2(size.x + pad, size.y * 0.42), Color(0.03, 0.07, 0.12, 0.7), 4.0)
		n.draw_line(Vector2(-pad, size.y * 0.3), Vector2(size.x + pad, size.y * 0.3), Color(Pal.EYES.r, Pal.EYES.g, Pal.EYES.b, 0.22), 3.0)
	if mood.get("glass", false):
		# The glasshouse: iron glazing bars, and what has grown through them.
		var x := 0.0
		while x < size.x:
			n.draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.04, 0.09, 0.12, 0.8), 5.0)
			x += 2.0 * TILE
		for i in 4:
			var y := size.y * i / 4.0
			n.draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.04, 0.09, 0.12, 0.8), 4.0)
		for i in 26:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			_frond(n, p, rng.randf_range(60.0, 190.0), rng.randf_range(-2.4, -0.7), Color(0.05, 0.14, 0.15, 0.9), rng)
	# Skirting.
	n.draw_rect(Rect2(-pad, size.y - 26.0, size.x + pad * 2.0, 26.0), Color(line.r, line.g, line.b, 0.55))


func _covered(spans: Array, x: float, margin: float) -> bool:
	for s: Vector2 in spans:
		if x > s.x - margin and x < s.y + margin:
			return true
	return false


func _grad_rect(n: Node2D, rect: Rect2, top: Color, bottom: Color) -> void:
	n.draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _window(n: Node2D, cx: float, base: float, w: float, h: float, wall: Color) -> void:
	var frame := Color(wall.r * 0.5, wall.g * 0.5, wall.b * 0.58, 1.0)
	n.draw_colored_polygon(_arch(cx, base, w + 22.0, h + 20.0), frame)
	var pane := _arch(cx, base - 10.0, w, h)
	var cols := PackedColorArray()
	for p in pane:
		var k := clampf((base - p.y) / h, 0.0, 1.0)
		cols.append(Color(wall.r * 1.25, wall.g * 1.25, wall.b * 1.3).lerp(Color(wall.r * 1.7, wall.g * 1.6, wall.b * 1.55), (1.0 - k) * 0.8))
	n.draw_polygon(pane, cols)
	n.draw_line(Vector2(cx, base - 10.0), Vector2(cx, base - h * 0.62), frame, 6.0)
	n.draw_line(Vector2(cx - w * 0.5, base - h * 0.42), Vector2(cx + w * 0.5, base - h * 0.42), frame, 5.0)
	n.draw_arc(Vector2(cx, base - h * 0.74), w * 0.13, 0, TAU, 20, frame, 5.0)
	n.draw_arc(Vector2(cx - w * 0.25, base - h * 0.56), w * 0.22, PI, TAU, 12, frame, 6.0)
	n.draw_arc(Vector2(cx + w * 0.25, base - h * 0.56), w * 0.22, PI, TAU, 12, frame, 6.0)


func _shelves(n: Node2D, size: Vector2, covered: Array, wall: Color, rng: RandomNumberGenerator) -> void:
	# Bookcases to the ceiling, as in the study mockup: dark carcass, rows of spines.
	var case_w := 5.0 * TILE
	var x := 0.6 * TILE
	while x + case_w < size.x:
		if _covered(covered, x + case_w * 0.5, case_w * 0.5):
			x += case_w + 1.2 * TILE
			continue
		var top := 0.9 * TILE
		var bottom := size.y - 0.4 * TILE
		n.draw_rect(Rect2(x - 10.0, top - 14.0, case_w + 20.0, bottom - top + 14.0), Color(wall.r * 0.35, wall.g * 0.35, wall.b * 0.42))
		var row := 76.0
		var y := top
		while y + row < bottom:
			n.draw_rect(Rect2(x, y, case_w, row - 10.0), Color(wall.r * 0.52, wall.g * 0.5, wall.b * 0.6))
			var bx := x + 4.0
			while bx < x + case_w - 8.0:
				var bw := rng.randf_range(7.0, 16.0)
				var bh := rng.randf_range(row * 0.5, row * 0.8)
				if rng.randf() < 0.9:
					var tone := rng.randf_range(0.7, 1.25)
					n.draw_rect(Rect2(bx, y + row - 10.0 - bh, bw - 2.0, bh), Color(wall.r * tone, wall.g * tone * 0.95, wall.b * tone * 1.05))
				bx += bw
			y += row
		x += case_w + 1.2 * TILE


func _frond(n: Node2D, at: Vector2, length: float, angle: float, col: Color, rng: RandomNumberGenerator) -> void:
	var pts := PackedVector2Array()
	var p := at
	var a := angle
	for i in 8:
		pts.append(p)
		p += Vector2(cos(a), sin(a)) * length / 8.0
		a += rng.randf_range(-0.25, 0.3)
	n.draw_polyline(pts, col, 5.0, true)
	for i in range(2, 8):
		var q := pts[i]
		for side: float in [-1.0, 1.0]:
			n.draw_line(q, q + Vector2(cos(a + side * 1.2), sin(a + side * 1.2)) * length * 0.18, col, 3.0, true)


# ===================================================================== plates
func _build_plates() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for p: Dictionary in data.get("props", []):
		var sprite: String = p["sprite"]
		if not sprite.begins_with("plate:"):
			continue
		var key := sprite.trim_prefix("plate:")
		var path := "res://assets/plates/%s.png" % key
		if not ResourceLoader.exists(path):
			continue
		var s := Sprite2D.new()
		s.texture = load(path)
		s.centered = false
		var sc := float(p.get("scale", 1.0))
		var flip: bool = p.get("flip", false)
		var size := s.texture.get_size() * sc
		s.scale = Vector2(-sc if flip else sc, sc)
		s.position = Vector2(float(p["x"]) * TILE + (size.x if flip else 0.0), float(p["y"]) * TILE - size.y + 6.0)
		s.z_index = -50
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(s)
		# The painted candles get a live flame-glow laid over them.
		for c: Array in p.get("candles", []):
			var local := Vector2(c[0], c[1]) * sc
			if flip:
				local.x = size.x - local.x
			var at := Vector2(float(p["x"]) * TILE, float(p["y"]) * TILE - size.y + 6.0) + local
			for big: bool in [true, false]:
				var g := Sprite2D.new()
				g.texture = _glow_tex
				g.material = add
				g.position = at
				g.z_index = -30
				g.modulate = Color(1.0, 0.5, 0.56, 0.3) if big else Color(1.0, 0.82, 0.66, 0.6)
				add_child(g)
				_candles.append({"node": g, "base": 6.5 if big else 0.6, "ph": at.x * 0.013 + (0.0 if big else 2.0), "a": g.modulate.a})


# ===================================================================== lights
func _build_lights() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for p: Dictionary in data.get("props", []):
		var kind: String = p["sprite"]
		if kind != "candle" and kind != "lamp":
			continue
		var at := Vector2(p["x"], p["y"]) * TILE
		var holder := _add_drawer(-28, _draw_candlestick.bind(kind))
		holder.position = at
		var flame := at + (Vector2(0, -150) if kind == "candle" else Vector2(0, -300))
		var warm := kind == "candle"
		for big: bool in [true, false]:
			var g := Sprite2D.new()
			g.texture = _glow_tex
			g.material = add
			g.position = flame
			g.z_index = -27
			if warm:
				g.modulate = Color(1.0, 0.5, 0.56, 0.3) if big else Color(1.0, 0.82, 0.66, 0.6)
			else:
				g.modulate = Color(0.4, 0.85, 1.0, 0.16) if big else Color(0.7, 0.95, 1.0, 0.5)
			add_child(g)
			_candles.append({"node": g, "base": 7.5 if big else 0.7, "ph": at.x * 0.013 + (0.0 if big else 2.0),
				"a": g.modulate.a, "steady": not warm})


func _draw_candlestick(n: Node2D, kind: String) -> void:
	var c := Color(0.045, 0.04, 0.09)
	if kind == "lamp":
		# Father's lamps: a caged tube on a bracket.
		n.draw_rect(Rect2(-5, -330, 10, 60), c)
		n.draw_rect(Rect2(-16, -320, 32, 44), Color(0.75, 0.95, 1.0))
		n.draw_rect(Rect2(-20, -326, 40, 6), c)
		n.draw_rect(Rect2(-20, -278, 40, 6), c)
		return
	# A three-branch floor candelabrum, like the ones in the mockups.
	n.draw_colored_polygon(PackedVector2Array([Vector2(-20, 0), Vector2(20, 0), Vector2(4, -14), Vector2(-4, -14)]), c)
	n.draw_rect(Rect2(-3, -112, 6, 100), c)
	n.draw_arc(Vector2(0, -128), 22.0, 0.15, PI - 0.15, 14, c, 4.0)
	for dx: float in [-22.0, 0.0, 22.0]:
		var top := -126.0 if dx != 0.0 else -112.0
		n.draw_rect(Rect2(dx - 6, top - 4, 12, 4), c)
		n.draw_rect(Rect2(dx - 3, top - 26, 6, 22), Color(0.78, 0.74, 0.88))
		n.draw_circle(Vector2(dx, top - 32), 4.0, Color(1.0, 0.9, 0.8))


func _draw_columns(n: Node2D) -> void:
	# Piers at the depth of the back wall: from each floor to whatever is above it.
	var shaft := Color(0.075, 0.07, 0.165)
	var lit := Color(0.16, 0.15, 0.32)
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
			# every floor in this column of the room
			var y := int(r["y"] + r["h"])
			while not blocked and y > int(r["y"]):
				if solid(x, y) and solid(x + 1, y) and not solid(x, y - 1) and not solid(x + 1, y - 1):
					var top := y - 1
					while top > int(r["y"]) - 1 and not solid(x, top) and not solid(x + 1, top):
						top -= 1
					if y - top - 1 >= 5:
						_column(n, (x + 1) * TILE, y * TILE, (top + 1) * TILE, shaft, lit)
					y = top
				else:
					y -= 1
			x += 9


func _column(n: Node2D, cx: float, base: float, top: float, shaft: Color, lit: Color) -> void:
	var w := 34.0
	n.draw_rect(Rect2(cx - w * 0.5, top, w, base - top), shaft)
	n.draw_rect(Rect2(cx - w * 0.5 + 5.0, top + 60.0, 4.0, base - top - 110.0), lit)
	# base: plinth and two rolls
	n.draw_rect(Rect2(cx - w * 0.5 - 14.0, base - 20.0, w + 28.0, 20.0), shaft)
	n.draw_rect(Rect2(cx - w * 0.5 - 8.0, base - 34.0, w + 16.0, 14.0), shaft)
	n.draw_rect(Rect2(cx - w * 0.5 - 4.0, base - 62.0, w + 8.0, 8.0), shaft)
	# capital
	n.draw_rect(Rect2(cx - w * 0.5 - 16.0, top, w + 32.0, 16.0), shaft)
	n.draw_rect(Rect2(cx - w * 0.5 - 9.0, top + 16.0, w + 18.0, 14.0), shaft)
	n.draw_rect(Rect2(cx - w * 0.5 - 4.0, top + 48.0, w + 8.0, 8.0), shaft)
	n.draw_line(Vector2(cx - w * 0.5 - 16.0, top + 16.0), Vector2(cx + w * 0.5 + 16.0, top + 16.0), lit, 2.0)


# ======================================================================= mass
func _build_mass() -> void:
	_add_drawer(-40, _draw_columns)
	_add_drawer(0, _draw_mass)
	_add_drawer(-5, _draw_rails)
	_add_drawer(20, _draw_hanging)
	_add_drawer(1, _draw_vaults)


func _draw_mass(n: Node2D) -> void:
	# Everything that collides, in one ink. Bleeds past the level's edge so the
	# camera never finds the end of the earth.
	var bleed := 40.0 * TILE
	var world := Vector2(_w, _h) * TILE
	n.draw_rect(Rect2(-bleed, -bleed, bleed, world.y + bleed * 2.0), Pal.INK)
	n.draw_rect(Rect2(world.x, -bleed, bleed, world.y + bleed * 2.0), Pal.INK)
	n.draw_rect(Rect2(0, -bleed, world.x, bleed), Pal.INK)
	n.draw_rect(Rect2(0, world.y, world.x, bleed), Pal.INK)
	for r: Array in data["solids"]:
		n.draw_rect(Rect2(Vector2(r[0], r[1]) * TILE - Vector2(1, 1), Vector2(r[2], r[3]) * TILE + Vector2(2, 2)), Pal.INK)
	for s: Dictionary in data["slopes"]:
		var poly := PackedVector2Array()
		for p: Array in s["pts"]:
			poly.append(Vector2(p[0], p[1]) * TILE)
		n.draw_colored_polygon(poly, Pal.INK)
		_draw_stair_treads(n, s)
	for o: Dictionary in data["oneways"]:
		var x0: float = o["x"] * TILE
		var y0: float = o["y"] * TILE
		var ow: float = o["w"] * TILE
		n.draw_rect(Rect2(x0, y0, ow, 14.0), Pal.INK)
		n.draw_line(Vector2(x0, y0 + 1.0), Vector2(x0 + ow, y0 + 1.0), Pal.EDGE, 3.0)
		if o.get("kind", "") == "lamp":
			# hung on two chains, lit
			for cx: float in [x0 + 16.0, x0 + ow - 16.0]:
				n.draw_line(Vector2(cx, y0), Vector2(cx - TILT * 400.0, y0 - 500.0), Pal.INK, 4.0)
			n.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 20, y0 + 14), Vector2(x0 + ow - 20, y0 + 14), Vector2(x0 + ow * 0.5, y0 + 60)]), Pal.INK)
		else:
			for cx: float in [x0 + 10.0, x0 + ow - 10.0]:
				n.draw_rect(Rect2(cx - 6.0, y0 - 6.0, 12.0, 26.0), Pal.INK)

	# Lit edges. Floors catch the light along the top; walls and soffits only faintly.
	var floor_c := Pal.EDGE
	var faint := Color(Pal.EDGE.r, Pal.EDGE.g, Pal.EDGE.b, 0.45)
	for y in range(1, _h):
		var x := 0
		while x < _w:
			if solid(x, y) and not solid(x, y - 1):
				var x0 := x
				while x < _w and solid(x, y) and not solid(x, y - 1):
					x += 1
				var a := Vector2(x0, y) * TILE
				var b := Vector2(x, y) * TILE
				n.draw_line(a + Vector2(0, 1.5), b + Vector2(0, 1.5), floor_c, 3.0)
				n.draw_line(a + Vector2(6, 9), b + Vector2(-6, 9), Color(floor_c.r, floor_c.g, floor_c.b, 0.35), 2.0)
				# flagstone joints
				var jx := a.x + 40.0 + float((x0 * 37 + y * 11) % 50)
				while jx < b.x - 20.0:
					n.draw_line(Vector2(jx, a.y + 2.0), Vector2(jx, a.y + 9.0), Color(floor_c.r, floor_c.g, floor_c.b, 0.5), 2.0)
					jx += 70.0 + float((int(jx) * 7) % 60)
			else:
				x += 1
	for x in range(1, _w):
		var y := 0
		while y < _h:
			var left := solid(x - 1, y) and not solid(x, y)
			var right := solid(x, y) and not solid(x - 1, y)
			if left or right:
				var y0 := y
				while y < _h and ((left and solid(x - 1, y) and not solid(x, y)) or (right and solid(x, y) and not solid(x - 1, y))):
					y += 1
				var px := x * TILE + (1.5 if left else -1.5)
				n.draw_line(Vector2(px, y0 * TILE), Vector2(px, y * TILE), faint, 2.0)
			else:
				y += 1


func _draw_stair_treads(n: Node2D, s: Dictionary) -> void:
	# The ramp is one smooth collision edge; the treads are drawn just under it.
	var l: Array = s["line"]
	var a := Vector2(l[0], l[1]) * TILE
	var b := Vector2(l[2], l[3]) * TILE
	var steps := int(absf(b.x - a.x) / 32.0)
	if steps < 1:
		return
	var d := (b - a) / steps
	var pts := PackedVector2Array()
	for i in steps:
		var p := a + d * i
		var q := a + d * (i + 1)
		var up := d.y < 0.0
		# riser then tread, tucked 3 px under the walking line
		if up:
			pts.append(p + Vector2(0, 3))
			pts.append(Vector2(p.x, q.y) + Vector2(0, 3))
		else:
			pts.append(p + Vector2(0, 3))
			pts.append(Vector2(q.x, p.y) + Vector2(0, 3))
	pts.append(b + Vector2(0, 3))
	n.draw_polyline(pts, Pal.EDGE, 2.5)
	n.draw_line(a, b, Color(Pal.EDGE.r, Pal.EDGE.g, Pal.EDGE.b, 0.5), 2.0)


func _draw_rails(n: Node2D) -> void:
	# Balustrades: on every stair, and along every gallery (a floor with open
	# air under it). Drawn behind Cowl so they never hide him.
	var c := Color(0.05, 0.045, 0.1)
	for s: Dictionary in data["slopes"]:
		var l: Array = s["line"]
		_rail(n, Vector2(l[0], l[1]) * TILE, Vector2(l[2], l[3]) * TILE, c)
	for y in range(2, _h - 3):
		var x := 0
		while x < _w:
			var gallery := solid(x, y) and not solid(x, y - 1) and not solid(x, y - 2) and solid(x, y + 1) and not solid(x, y + 2) and not solid(x, y + 3)
			if gallery:
				var x0 := x
				while x < _w and solid(x, y) and not solid(x, y - 1) and not solid(x, y + 2):
					x += 1
				if x - x0 >= 4:
					_rail(n, Vector2(x0, y) * TILE, Vector2(x, y) * TILE, c)
			else:
				x += 1


func _rail(n: Node2D, a: Vector2, b: Vector2, c: Color) -> void:
	var length := a.distance_to(b)
	var count := maxi(int(length / 40.0), 1)
	var hgt := 92.0
	n.draw_line(a + Vector2(0, -hgt), b + Vector2(0, -hgt), c, 7.0)
	n.draw_line(a + Vector2(0, -hgt * 0.22), b + Vector2(0, -hgt * 0.22), c, 3.0)
	for i in count + 1:
		var p := a.lerp(b, float(i) / count)
		var newel := i % 6 == 0
		n.draw_line(p, p + Vector2(0, -hgt - (26.0 if newel else 0.0)), c, 7.0 if newel else 3.0)
		if newel:
			# the spear finial of the mockups' ironwork
			n.draw_colored_polygon(PackedVector2Array([p + Vector2(-7, -hgt - 22), p + Vector2(0, -hgt - 52), p + Vector2(7, -hgt - 22)]), c)


func _draw_hanging(n: Node2D) -> void:
	# Tatters of moss and root under every soffit: the mockups' signature edge.
	# In front of Cowl, short, and never low enough to read as something to duck.
	for y in range(0, _h - 1):
		var x := 0
		while x < _w:
			if solid(x, y) and not solid(x, y + 1):
				var x0 := x
				while x < _w and solid(x, y) and not solid(x, y + 1):
					x += 1
				_tatters(n, x0, x, y + 1)
			else:
				x += 1


func _tatters(n: Node2D, x0: int, x1: int, y: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = x0 * 977 + y * 131
	var px := x0 * TILE
	var end := x1 * TILE
	var clump := 0.0                 # tatters come in clumps, with bare soffit between
	while px < end:
		var col := int(px / TILE)
		# How much clear air is under this soffit, in tiles?
		var room := 0
		while room < 8 and not solid(col, y + room):
			room += 1
		var max_len := clampf((room - 3.2) * TILE, 0.0, 1.7 * TILE)
		if clump <= 0.0:
			if rng.randf() < 0.45:
				px += rng.randf_range(30.0, 150.0)       # a bare stretch
			clump = rng.randf_range(60.0, 260.0)
			continue
		var w := rng.randf_range(7.0, 26.0)
		if max_len > 6.0:
			# Mostly short, now and then one long strand.
			var k := pow(rng.randf(), 2.6)
			var length := maxf(k * max_len, 5.0)
			var lean := length * TILT + rng.randf_range(-4.0, 4.0)
			var top_y := y * TILE - 1.0
			var tip := Vector2(px + w * 0.5 + lean, top_y + length)
			# a drip: straight-sided most of the way, then a rounded point
			n.draw_colored_polygon(PackedVector2Array([
				Vector2(px - 3.0, top_y), Vector2(px + w + 3.0, top_y),
				Vector2(px + w * 0.72 + lean * 0.6, top_y + length * 0.62), tip,
				Vector2(px + w * 0.28 + lean * 0.6, top_y + length * 0.62)]), Pal.INK)
		px += w * rng.randf_range(0.55, 1.1)
		clump -= w


func _draw_vaults(n: Node2D) -> void:
	# Gothic shoulders: every room's upper corners are filled with an arch
	# spandrel in ink, and wide rooms get pendant ribs along the ceiling. Only
	# where the wall and ceiling behind are unbroken and the air beneath is clear.
	for r: Dictionary in data["rooms"]:
		var rx := int(r["x"])
		var ry := int(r["y"])
		var rw := int(r["w"])
		var rh := int(r["h"])
		var rad := mini(mini(3, rw / 5), (rh - 5))
		if rad >= 2:
			for side: int in [-1, 1]:
				var cx := rx if side < 0 else rx + rw
				var wall_x := rx - 1 if side < 0 else rx + rw
				var inner_x := rx if side < 0 else rx + rw - 1
				var ok := true
				for i in rad + 3:
					if not solid(wall_x, ry + i):
						ok = false
				for i in rad + 1:
					if not solid(inner_x - side * i, ry - 1):
						ok = false
					for j in rad + 3:
						if solid(inner_x - side * i, ry + j):
							ok = false
				if ok:
					_spandrel(n, Vector2(cx, ry) * TILE, rad * TILE, -side)
		if rw >= 18:
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
					_pendant(n, Vector2(bx, ry) * TILE, minf(2.2, rh * 0.22) * TILE)


func _spandrel(n: Node2D, corner: Vector2, rad: float, dir: int) -> void:
	var pts := PackedVector2Array([corner])
	for k in 11:
		var a := k / 10.0 * PI * 0.5
		pts.append(corner + Vector2(dir * rad * (1.0 - sin(a)), rad * (1.0 - cos(a)) * 1.25))
	n.draw_colored_polygon(pts, Pal.INK)
	var edge := pts.slice(1)
	n.draw_polyline(edge, Color(Pal.EDGE.r, Pal.EDGE.g, Pal.EDGE.b, 0.5), 2.0, true)


func _pendant(n: Node2D, at: Vector2, depth: float) -> void:
	var w := depth * 1.5
	var pts := PackedVector2Array()
	for k in 9:
		var a := k / 8.0 * PI * 0.5
		pts.append(at + Vector2(-w + w * sin(a), depth * (1.0 - cos(a))))
	for k in range(8, -1, -1):
		var a := k / 8.0 * PI * 0.5
		pts.append(at + Vector2(w - w * sin(a), depth * (1.0 - cos(a))))
	n.draw_colored_polygon(pts, Pal.INK)
	n.draw_polyline(pts, Color(Pal.EDGE.r, Pal.EDGE.g, Pal.EDGE.b, 0.5), 2.0, true)


# ==================================================================== overlay
func _build_overlay() -> void:
	# Dust in the air, lit by whatever light there is.
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
	_dust.color = Color(0.75, 0.72, 1.0, 0.28)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_dust.color_ramp = ramp
	_dust.z_index = 25
	add_child(_dust)

	# Vignette: the dark presses in at the edges of the frame.
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
	float v = smoothstep(0.38, 0.86, d);
	COLOR = vec4(0.015, 0.01, 0.04, v * 0.78);
}"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	layer.add_child(rect)


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_2d()
	if cam != null and _dust != null:
		_dust.global_position = cam.get_screen_center_position()
	for c: Dictionary in _candles:
		var g: Sprite2D = c["node"]
		var ph: float = c["ph"]
		var f := 1.0 + sin(_t * 9.0 + ph) * 0.05 + sin(_t * 17.3 + ph * 2.1) * 0.035 + sin(_t * 2.1 + ph) * 0.04
		if c.get("steady", false):
			f = 1.0 + sin(_t * 1.3 + ph) * 0.03
		var base: float = c["base"]
		g.scale = Vector2(base, base) * f
		g.modulate.a = float(c["a"]) * (0.9 + (f - 1.0) * 2.0)
