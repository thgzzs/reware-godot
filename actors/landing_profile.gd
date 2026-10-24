class_name LandingProfile
extends Resource
@export var minimum_air_seconds := 0.08
@export var minimum_drop := 0.22
@export var minimum_impact_speed := 2.5
@export var blend_in_seconds := 0.035
@export var blend_out_seconds := 0.10
@export var standing_clips := PackedStringArray(["FALL_land","JUMP_land"])
@export var moving_clips := PackedStringArray(["JUMP_land","FALL_land"])

@export var moving_min_speed := 0.7
@export var minimum_moving_playback := 0.4
@export var maximum_moving_playback := 1.5
