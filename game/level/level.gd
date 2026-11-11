class_name Level
extends Node2D
## Builds a playable level from the JSON written by tools/levelkit.py.
##
## Collision and decoration are separate on purpose. This node makes the
## collision (solid mass, ramps, one-way platforms) and the gameplay pieces;
## LevelArt (level_art.gd) dresses the same data and never collides.

const TILE := 64.0
const ENTITY_SCRIPTS := {
	"vine": "res://game/world/vine_barrier.gd",
	"knife": "res://game/world/knife_pickup.gd",
	"crawler": "res://game/enemies/crawler.gd",
	"drifter": "res://game/enemies/drifter.gd",
	"dummy": "res://game/enemies/dummy.gd",
	"spikes": "res://game/world/spikes.gd",
	"checkpoint": "res://game/world/checkpoint.gd",
	"lift": "res://game/world/lift.gd",
	"lever": "res://game/world/lever.gd",
	"hint": "res://game/world/hint.gd",
	"false_wall": "res://game/world/false_wall.gd",
	"bookcase_door": "res://game/world/bookcase_door.gd",
	"note": "res://game/world/note.gd",
	"family": "res://game/world/fixture.gd",
	"biome_door": "res://game/world/fixture.gd",
	"crack": "res://game/world/fixture.gd",
	"lab_door": "res://game/world/fixture.gd",
	"glint": "res://game/world/fixture.gd",
	"front_door": "res://game/world/fixture.gd",
	"garage_door": "res://game/world/fixture.gd",
}

@export_file("*.json") var data_path := ""
## Draw the black-and-pale blockout instead of the art.
@export var blockout_view := false

var data: Dictionary = {}
var size_px := Vector2.ZERO
var spawn_px := Vector2.ZERO
var entities_by_type: Dictionary = {}

var _solids: StaticBody2D
var _oneways: StaticBody2D


func _ready() -> void:
	if data_path != "":
		build(data_path)


func build(path: String) -> void:
	data_path = path
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "Level data did not parse: " + path)
	data = parsed
	size_px = Vector2(data["w"], data["h"]) * TILE
	spawn_px = Vector2(data["spawn"][0], data["spawn"][1]) * TILE
	_build_collision()
	_build_entities()
	queue_redraw()


func world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size_px)


# ================================================================== collision
func _build_collision() -> void:
	_solids = StaticBody2D.new()
	_solids.name = "Solids"
	_solids.collision_layer = 1
	_solids.collision_mask = 0
	add_child(_solids)
	for r: Array in data["solids"]:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(r[2], r[3]) * TILE
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = (Vector2(r[0], r[1]) + Vector2(r[2], r[3]) * 0.5) * TILE
		_solids.add_child(cs)
	for s: Dictionary in data["slopes"]:
		var poly := PackedVector2Array()
		for p: Array in s["pts"]:
			poly.append(Vector2(p[0], p[1]) * TILE)
		var shape := ConvexPolygonShape2D.new()
		shape.points = poly
		var cs := CollisionShape2D.new()
		cs.shape = shape
		_solids.add_child(cs)

	_oneways = StaticBody2D.new()
	_oneways.name = "Oneways"
	_oneways.collision_layer = 2
	_oneways.collision_mask = 0
	add_child(_oneways)
	for o: Dictionary in data["oneways"]:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(o["w"] * TILE, 14.0)
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.one_way_collision = true
		cs.one_way_collision_margin = 6.0
		cs.position = Vector2((o["x"] + o["w"] * 0.5) * TILE, o["y"] * TILE + 7.0)
		_oneways.add_child(cs)


# =================================================================== entities
func _build_entities() -> void:
	var holder := Node2D.new()
	holder.name = "Entities"
	add_child(holder)
	for e: Dictionary in data["entities"]:
		var kind: String = e["type"]
		if not ENTITY_SCRIPTS.has(kind):
			push_warning("Level: unknown entity type '%s'" % kind)
			continue
		var path: String = ENTITY_SCRIPTS[kind]
		if not ResourceLoader.exists(path):
			continue
		var script: GDScript = load(path)
		var node: Node2D = script.new()
		node.name = "%s_%d" % [kind, holder.get_child_count()]
		node.position = Vector2(e["x"], e["y"]) * TILE
		node.set_meta(&"spec", e)
		if node.has_method(&"configure"):
			node.call(&"configure", e)
		holder.add_child(node)
		if not entities_by_type.has(kind):
			entities_by_type[kind] = []
		entities_by_type[kind].append(node)


func rooms() -> Array:
	return data.get("rooms", [])


func zones() -> Array:
	return data.get("zones", [])


func room_at(pos: Vector2) -> Dictionary:
	var t := pos / TILE
	var best: Dictionary = {}
	var best_area := INF
	for r: Dictionary in rooms():
		if t.x >= r["x"] and t.x < r["x"] + r["w"] and t.y >= r["y"] and t.y <= r["y"] + r["h"]:
			var area: float = r["w"] * r["h"]
			if area < best_area:
				best = r
				best_area = area
	return best


# =================================================================== blockout
func _draw() -> void:
	if not (blockout_view or Game.debug_collision) or data.is_empty():
		return
	var mass := Color(0.03, 0.028, 0.045)
	var space := Color(0.62, 0.6, 0.72) if blockout_view else Color(0, 0, 0, 0)
	var edge := Color(0.95, 0.75, 0.3, 0.9)
	if blockout_view:
		draw_rect(Rect2(Vector2.ZERO, size_px), space)
	for r: Array in data["solids"]:
		var rect := Rect2(Vector2(r[0], r[1]) * TILE, Vector2(r[2], r[3]) * TILE)
		if blockout_view:
			draw_rect(rect, mass)
		else:
			draw_rect(rect, edge, false, 3.0)
	for s: Dictionary in data["slopes"]:
		var poly := PackedVector2Array()
		for p: Array in s["pts"]:
			poly.append(Vector2(p[0], p[1]) * TILE)
		if blockout_view:
			draw_colored_polygon(poly, mass)
		else:
			poly.append(poly[0])
			draw_polyline(poly, edge, 3.0)
	for o: Dictionary in data["oneways"]:
		draw_rect(Rect2(o["x"] * TILE, o["y"] * TILE, o["w"] * TILE, 14.0), Color(0.85, 0.5, 0.15))
	if blockout_view:
		var font := ThemeDB.fallback_font
		for l: Array in data.get("labels", []):
			draw_string(font, Vector2(l[0], l[1]) * TILE + Vector2(0, 28), str(l[2]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.25, 0.2, 0.4))
