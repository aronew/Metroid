class_name ContactDamage
extends Area2D
## An area that hurts Cowl when his hurtbox touches it.

var damage := 1


func _init() -> void:
	collision_layer = 64
	collision_mask = 0
	monitoring = false
	monitorable = true


func get_contact_damage() -> int:
	return damage
