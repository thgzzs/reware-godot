class_name InteractionProfile
extends Resource
@export var reach := 3.0
@export var enter_seconds := 0.65
@export var exit_seconds := 0.55
@export var enter_open_seconds := 0.12
@export var enter_close_seconds := 0.12
@export var exit_close_seconds := 0.10
@export var open_motion_start := 0.41
@export var entry_close_motion_start := 0.20
@export var exit_open_motion_start := 0.06
@export var exit_close_motion_start := 0.10
@export var max_transition_speed := 1.25
@export var floor_max_drop := 2.0
@export var exit_offsets := PackedVector3Array([Vector3(-1.65,0,0),Vector3(1.65,0,0),Vector3(0,0,2.8)])

