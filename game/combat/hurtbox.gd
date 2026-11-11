class_name Hurtbox
extends Area2D
## Something the knife can hit. The swing calls take_hit on this area, which
## forwards it to whoever owns it. Return true if the blow landed.

var owner_node: Node


func _init() -> void:
	collision_layer = 32
	collision_mask = 0
	monitoring = false
	monitorable = true


func take_hit(info: Dictionary) -> bool:
	if owner_node != null and owner_node.has_method(&"take_hit"):
		return owner_node.call(&"take_hit", info)
	return false
