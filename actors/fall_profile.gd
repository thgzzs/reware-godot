class_name FallProfile
extends Resource
## SI units. Environmental landing damage is independent of combat defense stats.
@export var damage_enabled := true
@export var physical_tumble_enabled := true
@export var physical_tumble_drop := 4.0
@export var physical_tumble_speed := 14.0
@export var minimum_air_seconds := 0.24
@export var minimum_drop := 1.4
@export var descent_seconds := 0.12
@export var descent_speed := 2.0
@export var safe_impact_speed := 9.5
@export var damage_coefficient := 1.25
@export var maximum_damage := 200.0
@export var hard_landing_speed := 10.5
@export var fall_clips := PackedStringArray(["FALL_fall","JUMP_glide"])
@export var glide_clips := PackedStringArray(["FALL_glide","JUMP_glide"])
@export var landing_clips := PackedStringArray(["FALL_land","JUMP_land"])
@export var death_clips := PackedStringArray(["FALL_collapse","FALL_front"])
