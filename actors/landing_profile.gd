class_name LandingProfile
extends Resource
@export var minimum_air_seconds := 0.08
@export var minimum_drop := 0.22
@export var minimum_impact_speed := 2.5
@export var running_speed := 3.0
@export var blend_in_seconds := 0.035
@export var blend_out_seconds := 0.10
@export var standing_clips := PackedStringArray(["FALL_land","JUMP_land"])
@export var moving_clips := PackedStringArray(["JUMP_land","FALL_land"])
