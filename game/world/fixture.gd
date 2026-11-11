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
var painted := false       # already in the room's painted plate: do not draw


func configure(spec: Dictionary) -> void:
	kind = spec["type"]
	who = spec.get("who", "")
	painted = spec.get("painted", false)
	w = float(spec.get("w", 1)) * Game.TILE
	h = float(spec.get("h", 2)) * Game.TILE


## Kit art for each fixture (W32 sealed doors, W33 secret pieces), fitted to
## the rectangle the level gives it.
const ART := {
	"front_door": "doors/front_door", "garage_door": "doors/garage_shutter",
	"lab_door": "doors/lab_vault", "crack": "doors/cracked_floor",
}


func _ready() -> void:
	# Doors belong to the back wall: behind the house's ink edges. The cracked
	# floor is part of the floor, so it sits over the ink.
	z_index = -20 if kind in ["front_door", "garage_door", "biome_door", "lab_door"] else 4
	if kind == "crack":
		z_index = 3
	if kind != "glint":
		add_to_group(&"interactable")


func _art_key() -> String:
	if kind == "biome_door":
		return "doors/green_door" if h >= 5.0 * Game.TILE else "doors/green_door_small"
	return ART.get(kind, "")


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
	var key := _art_key()
	if key != "":
		var t := Kit.tex(key)
		if kind == "crack":
			# its walking top on the floor line, the cracks running down into the slab
			draw_texture_rect(t, Rect2(0, -6, w, t.get_height() * w / t.get_width()), false, Color(0.7, 0.68, 0.8))
		else:
			draw_texture_rect(t, Rect2(0, -h, w, h), false)
	match kind:
		"family":
			if not painted:
				_draw_figure()
			# Time has stopped on them: a thin, slow shimmer.
			for i in 3:
				var y := -30.0 - 50.0 * i + sin(_t * 0.5 + i) * 6.0
				draw_arc(Vector2(0, y), 46.0 + 6.0 * i, 0.3 + _t * 0.1, 1.5 + _t * 0.1, 12, Color(Pal.EYES.r, Pal.EYES.g, Pal.EYES.b, 0.07), 2.0)
		"biome_door":
			# light from the other side, under and around the door
			var pulse := 0.6 + sin(_t * 1.4) * 0.2
			for i in 4:
				draw_circle(Vector2(w * 0.5, -h * 0.3), 50.0 + i * 44.0, Color(Pal.GREEN.r, Pal.GREEN.g, Pal.GREEN.b, 0.03 * pulse))
		"lab_door":
			# the empty socket, faintly alive
			var pulse := 0.5 + sin(_t * 1.1) * 0.25
			var c := Vector2(w * 0.5, -h * 0.5)
			for i in 3:
				draw_circle(c, 30.0 + 22.0 * i, Color(Pal.EYES.r, Pal.EYES.g, Pal.EYES.b, 0.035 * pulse))
		"glint":
			var g := pow(maxf(sin(_t * 1.3), 0.0), 8.0)
			draw_circle(Vector2(0, -30), 20.0, Color(1, 1, 1, 0.06 + 0.1 * g))
			draw_line(Vector2(-18 * g, -30), Vector2(18 * g, -30), Color(1, 1, 1, g), 2.0)
			draw_line(Vector2(0, -30 - 18 * g), Vector2(0, -30 + 18 * g), Color(1, 1, 1, g), 2.0)
			draw_circle(Vector2(0, -30), 3.0, Color(0.9, 0.95, 1.0, 0.8))


func _draw_figure() -> void:
	draw_circle(Vector2(0, -100), 26.0, Pal.INK)
	draw_rect(Rect2(-18, -78, 36, 78), Pal.INK)
	draw_rect(Rect2(-14, -106, 10, 4), Pal.EYES)
	draw_rect(Rect2(4, -106, 10, 4), Pal.EYES)


