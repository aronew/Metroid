class_name HitFx
## Where a blow lands: the light impact flash from Cowl's effects sheet
## (H22), tinted. Heavier blows add their own flash, flare and soot (see
## cowl_rig.gd, on attack_connected).


static func spawn(near: Node, at: Vector2, direction: int, color: Color = Color(0.86, 0.92, 1.0)) -> void:
	FxPlay.play(near, "flash_light", at, direction, color)
