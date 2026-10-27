class_name GameplayCommand
extends RefCounted
## One physics-tick intent. Replace the producer for AI/replay/network input.
var move := Vector2.ZERO
var jump := false
var aim := false
var fire := false
var reload := false
var interact := false
var sprint := false
var sprint_pressed := false
var locomotion_scale := 1.0
var walk := false
var brake := false
var look := Vector2.ZERO
## Dimensionless right-stick rate; mouse/touch look remains an accumulated delta.
var look_stick := Vector2.ZERO
var weapon_step := 0
var weapon_slot := -1
var respawn := false
var crouch := false
var camera_cycle := false
var switch_seat := false
var repair_vehicle := false

