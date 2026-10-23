class_name ReactionRestProfile
extends Resource
## Settling changes presentation only; the Jolt torso retains collision ownership.
@export var linear_speed := 1.0
@export var angular_speed := 1.3
@export var contact_seconds := 0.30
@export var blend_rate := 5.0
@export var unlock_speed := 2.2
@export var unlock_angular_speed := 2.5
@export var prone_clips := PackedStringArray(["KO_skid_back","FALL_front"])
@export var supine_clips := PackedStringArray(["KO_skid_front","FALL_back"])
@export var prone_getup := PackedStringArray(["GETUP_front","GETUP"])
@export var supine_getup := PackedStringArray(["GETUP","GETUP_front"])
