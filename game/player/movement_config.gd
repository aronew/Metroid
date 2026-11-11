class_name MovementConfig
extends Resource
## Every number that shapes how Cowl moves, in one place.
##
## Distances are in TILES (1 tile = 64 px) and times in seconds, so the same
## numbers can be read by the level tools. The controller converts to pixels.
## Jump arcs are authored as "how high" and "how long", never as raw gravity:
## change the height or the timing and gravity follows.

const TILE := 64.0

@export_group("Ground")
## Top running speed, tiles per second.
@export var run_speed := 8.6
## Stick deflection below this fraction walks instead of runs.
@export var walk_threshold := 0.55
## Walking speed, tiles per second (analog stick only).
@export var walk_speed := 3.4
## Seconds from standstill to top speed.
@export var accel_time := 0.085
## Seconds from top speed to standstill with no input.
@export var decel_time := 0.07
## Seconds to kill the old speed when the stick is reversed. Shorter than
## accel_time, so a turn bites at once but the body still has to brake.
@export var turn_time := 0.055

@export_group("Jump")
## Height of a full, held jump, in tiles.
@export var jump_height := 3.35
## Seconds from take-off to the top of a full jump.
@export var time_to_apex := 0.36
## Gravity while falling, as a multiple of rising gravity. Above 1 the fall is
## faster than the rise, which reads as weight.
@export var fall_gravity_mult := 1.55
## Releasing jump while rising multiplies the upward speed by this, once.
@export var jump_cut_mult := 0.5
## Fastest fall, tiles per second.
@export var max_fall_speed := 24.0
## Near the top of a held jump gravity is scaled by this, giving a short hang
## in which to place the landing.
@export var apex_gravity_mult := 0.55
## The hang applies while vertical speed is below this, tiles per second.
@export var apex_threshold := 2.2
## A jump pressed this long before landing still fires.
@export var jump_buffer := 0.12
## A jump pressed this long after walking off a ledge still fires.
@export var coyote_time := 0.1

@export_group("Air")
## Seconds from zero to top speed in the air.
@export var air_accel_time := 0.11
## Seconds from top speed to zero in the air with no input. Longer than on the
## ground: momentum carries, but never out of the player's hands.
@export var air_decel_time := 0.2
## Seconds to reverse in the air.
@export var air_turn_time := 0.09
## Extra air acceleration during the apex hang (multiplier).
@export var apex_accel_bonus := 1.25

@export_group("Forgiveness")
## Bumping a ceiling corner by up to this many pixels slides Cowl round it.
@export var corner_correction_px := 14.0
## Clipping a ledge lip by up to this many pixels lifts Cowl onto it.
@export var ledge_snap_px := 12.0

@export_group("Dodge")
## Distance covered by a dodge, in tiles.
@export var dodge_distance := 3.6
## Length of the dodge, seconds.
@export var dodge_time := 0.24
## Seconds before another dodge is allowed, counted from the end of the last.
@export var dodge_cooldown := 0.35
## The dodge cannot be hurt from this moment...
@export var dodge_iframe_start := 0.02
## ...to this one.
@export var dodge_iframe_end := 0.2
## A jump may cancel the dodge after this fraction of it.
@export var dodge_jump_cancel := 0.55

@export_group("Landing")
## Falls faster than this (tiles/s) land heavily: bigger squash, dust, thump.
@export var heavy_land_speed := 19.0
## Seconds of rooted recovery after a heavy landing.
@export var heavy_land_recovery := 0.1

@export_group("Combat")
## Speed multiplier while a grounded swing is active.
@export var attack_move_mult := 0.35
## Seconds of invulnerability after being hurt.
@export var hurt_invuln := 1.1
## Seconds without control after being hurt.
@export var hurt_stun := 0.26
## Knockback speed when hurt, tiles per second (x, y up).
@export var hurt_knockback := Vector2(6.5, 7.0)


# ---------------------------------------------------------------- derived (px)
func gravity_up() -> float:
	return 2.0 * jump_height * TILE / (time_to_apex * time_to_apex)


func gravity_down() -> float:
	return gravity_up() * fall_gravity_mult


func jump_velocity() -> float:
	return gravity_up() * time_to_apex


func run_px() -> float:
	return run_speed * TILE


func walk_px() -> float:
	return walk_speed * TILE


func dodge_speed() -> float:
	# The dodge eases out, so its peak is above the mean; see Cowl._dodge_curve.
	return dodge_distance * TILE / dodge_time


func describe() -> String:
	## One-line summary of the envelope, for the lab's read-out.
	var t_fall := sqrt(2.0 * jump_height * TILE / gravity_down())
	var air := time_to_apex + t_fall
	return "rise %.2ft  flat gap %.1ft  air %.2fs  run %.1ft/s" % [
		jump_height, air * run_speed, air, run_speed]
