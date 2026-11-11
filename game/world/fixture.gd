extends Node2D
## Things in the house that are looked at rather than used: the frozen family,
## sealed doors, the cracked floor, the vault. One script, switched on the
## level data's `type`, so new set dressing with a line of text is one entry.
##
## Where a cut-out from the environment mockups exists (assets/props) it is
## used; otherwise the fixture is drawn as a plain silhouette in the mansion's
## ink, which is the mockups' own treatment of foreground shapes.

const LINES := {
	"mother": "Mum, at the stove. The ladle is lifted. The steam over the pot hangs there, as still as glass.",
	"sibling": "Sat at the table with the ball in both hands, mid-turn. Not asleep. Not anything.",
	"father": "Dad, at his desk, pen down on the page. He does not look up. He is not breathing, and he is not not breathing.",
	"biome_door": "The door hums against your palm, warm. Green light under it, and a smell like rain on metal. It will not open.",
	"crack": "The floor is cracked right through. Something far heavier than you could finish the job.",
	"front_door": "The front door. Earth has come in round the frame and packed itself hard. Roots as thick as your arm.",
	"garage_door": "The way through to the garage. The shutter has buckled inward under the weight of whatever is behind it.",
	"lab_door": "A round door, taller than the room should allow. No handle. In the middle, a socket the size of two cupped hands, perfectly smooth. Whatever sat in it is gone.",
}

var kind := ""
var who := ""
var w := 64.0
var h := 128.0
var _t := 0.0
var _sprite: Sprite2D


func configure(spec: Dictionary) -> void:
	kind = spec["type"]
	who = spec.get("who", "")
	w = float(spec.get("w", 1)) * Game.TILE
	h = float(spec.get("h", 2)) * Game.TILE


func _ready() -> void:
	z_index = 4
	if kind != "glint":
		add_to_group(&"interactable")
	var key := who if kind == "family" else kind
	var path := "res://assets/props/%s.png" % key
	if ResourceLoader.exists(path):
		_sprite = Sprite2D.new()
		_sprite.texture = load(path)
		_sprite.centered = false
		var size := _sprite.texture.get_size()
		_sprite.position = Vector2((w - size.x) * 0.5 if kind != "family" else -size.x * 0.5, -size.y)
		add_child(_sprite)


func _centre() -> Vector2:
	return global_position + (Vector2(0, -60) if kind == "family" else Vector2(w * 0.5, -h * 0.5))


func interact_origin() -> Vector2:
	return _centre()


func interact_prompt(cowl: Cowl) -> String:
	var reach := maxf(w * 0.5, 60.0) + 70.0
	if absf(cowl.global_position.x - _centre().x) > reach or absf(cowl.global_position.y - global_position.y) > 150.0:
		return ""
	return "Look  [E]"


func interact(_cowl: Cowl) -> void:
	var key := who if kind == "family" else kind
	Game.say(LINES.get(key, "..."), 6.5)
	if kind == "lab_door":
		Sfx.play(&"door_heavy")
		Game.set_flag("lab_door_seen")


func _process(delta: float) -> void:
	_t += delta
	if kind in ["biome_door", "glint", "lab_door", "family"]:
		queue_redraw()


func _draw() -> void:
	match kind:
		"family":
			if _sprite == null:
				_draw_figure()
			# Time has stopped on them: a thin, slow shimmer.
			for i in 3:
				var y := -30.0 - 50.0 * i + sin(_t * 0.5 + i) * 6.0
				draw_arc(Vector2(0, y), 46.0 + 6.0 * i, 0.3 + _t * 0.1, 1.5 + _t * 0.1, 12, Color(Pal.EYES.r, Pal.EYES.g, Pal.EYES.b, 0.07), 2.0)
		"biome_door":
			if _sprite == null:
				_draw_arch_door(Pal.GREEN)
		"lab_door":
			_draw_vault()
		"crack":
			_draw_crack()
		"glint":
			var g := pow(maxf(sin(_t * 1.3), 0.0), 8.0)
			draw_circle(Vector2(0, -30), 20.0, Color(1, 1, 1, 0.06 + 0.1 * g))
			draw_line(Vector2(-18 * g, -30), Vector2(18 * g, -30), Color(1, 1, 1, g), 2.0)
			draw_line(Vector2(0, -30 - 18 * g), Vector2(0, -30 + 18 * g), Color(1, 1, 1, g), 2.0)
			draw_circle(Vector2(0, -30), 3.0, Color(0.9, 0.95, 1.0, 0.8))
		"front_door":
			if _sprite == null:
				_draw_arch_door(Color(0, 0, 0, 0))
		"garage_door":
			draw_rect(Rect2(0, -h, w, h), Pal.INK_SOFT)
			for i in 9:
				var y := -h + i * h / 9.0
				draw_line(Vector2(0, y), Vector2(w, y + sin(i * 0.9) * 10.0), Pal.INK, 4.0)
			draw_rect(Rect2(-8, -h - 10, w + 16, 14), Pal.INK)


func _draw_figure() -> void:
	draw_circle(Vector2(0, -100), 26.0, Pal.INK)
	draw_rect(Rect2(-18, -78, 36, 78), Pal.INK)
	draw_rect(Rect2(-14, -106, 10, 4), Pal.EYES)
	draw_rect(Rect2(4, -106, 10, 4), Pal.EYES)


func _draw_arch_door(glow: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, 0))
	pts.append(Vector2(0, -h * 0.6))
	for i in 9:
		var f := i / 8.0
		pts.append(Vector2(w * 0.5 - cos(f * PI) * w * 0.5, -h * 0.6 - sin(f * PI) * h * 0.4))
	pts.append(Vector2(w, 0))
	draw_colored_polygon(pts, Pal.INK)
	if glow.a > 0.0:
		var pulse := 0.75 + sin(_t * 1.4) * 0.15
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(Vector2(w * 0.5, -h * 0.45) + (p - Vector2(w * 0.5, -h * 0.45)) * 0.72)
		draw_colored_polygon(inner, Color(glow.r * 0.25, glow.g * 0.4, glow.b * 0.2, pulse))
		for i in 4:
			draw_circle(Vector2(w * 0.5, -h * 0.4), 60.0 + i * 46.0, Color(glow.r, glow.g, glow.b, 0.035 * pulse))
		draw_line(Vector2(w * 0.5, -h * 0.85), Vector2(w * 0.5, 0), Color(glow.r, glow.g, glow.b, 0.5 * pulse), 3.0)


func _draw_vault() -> void:
	# The round door of the laboratory, set into the end wall.
	var c := Vector2(w * 0.5 + 20.0, -h * 0.5)
	var r := h * 0.47
	draw_rect(Rect2(-30, -h, w + 110, h), Pal.INK)
	draw_circle(c, r, Pal.INK_SOFT)
	draw_arc(c, r, 0, TAU, 64, Pal.EDGE, 6.0, true)
	draw_arc(c, r * 0.78, 0, TAU, 64, Color(Pal.WATER.r, Pal.WATER.g, Pal.WATER.b, 0.35), 3.0, true)
	for i in 12:
		var a := i * TAU / 12.0
		draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.9, 7.0, Pal.INK)
	for i in 3:
		var a := i * TAU / 3.0 + 0.5
		draw_line(c + Vector2(cos(a), sin(a)) * r * 0.25, c + Vector2(cos(a), sin(a)) * r * 0.76, Pal.INK, 12.0)
	var pulse := 0.5 + sin(_t * 1.1) * 0.25
	draw_circle(c, r * 0.2, Pal.INK)
	draw_arc(c, r * 0.2, 0, TAU, 32, Color(Pal.EYES.r, Pal.EYES.g, Pal.EYES.b, 0.5 + 0.3 * pulse), 3.0, true)
	for i in 3:
		draw_circle(c, r * (0.3 + 0.25 * i), Color(Pal.WATER.r, Pal.WATER.g, Pal.WATER.b, 0.04 * pulse))


func _draw_crack() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 5:
		var p := Vector2(w * rng.randf_range(0.1, 0.9), 0)
		var pts := PackedVector2Array([p])
		for k in 5:
			p += Vector2(rng.randf_range(-22, 22), rng.randf_range(8, 20))
			pts.append(p)
		draw_polyline(pts, Pal.HAZE, 3.0, true)
	draw_line(Vector2(0, 2), Vector2(w, 2), Pal.HAZE_MID, 2.0)
