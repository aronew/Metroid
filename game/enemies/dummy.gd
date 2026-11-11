extends Node2D
## A training dummy for the movement laboratory: takes hits, shows them.

var _flash := 0.0
var _lean := 0.0
var _lean_vel := 0.0
var _count := 0


func _ready() -> void:
	var area := Hurtbox.new()
	area.owner_node = self
	var shape := RectangleShape2D.new()
	shape.size = Vector2(56, 120)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -60)
	area.add_child(cs)
	add_child(area)


func take_hit(info: Dictionary) -> bool:
	_flash = 1.0
	_lean_vel += float(info["direction"]) * (9.0 + 4.0 * float(info["damage"]))
	_count += 1
	Sfx.play(&"hit")
	HitFx.spawn(self, info["at"], info["direction"])
	return true


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_lean_vel += (-_lean * 160.0 - _lean_vel * 9.0) * delta
	_lean += _lean_vel * delta
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, _lean * 0.3, Vector2.ONE)
	var c := Color(0.35, 0.3, 0.45).lerp(Color.WHITE, _flash)
	draw_rect(Rect2(-6, -60, 12, 60), Color(0.2, 0.17, 0.26))
	draw_rect(Rect2(-28, -120, 56, 70), c)
	draw_string(ThemeDB.fallback_font, Vector2(-10, -130), str(_count), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.2, 0.15, 0.3))
