class_name VehicleDoorProfile
extends Resource
@export var hinge_offsets := PackedVector3Array([Vector3(-0.91,0.1,-0.70),Vector3(0.91,0.1,-0.70),Vector3(-0.91,0.1,0.65),Vector3(0.91,0.1,0.65)])
@export var panel_size := Vector3(0.06,0.65,1.25)
@export var panel_mass := 18.0
@export_range(20,85) var opening_degrees := 68.0
@export var motor_impulse := 8.0
@export var motor_gain := 18.0
@export var maximum_motor_speed := 8.0
@export var latch_radians := 0.025
@export var seat_marker_adjustment := Vector3(0.13,-0.04,0.07)
@export var seat_offset := Vector3(-0.38,0.18,0.1)
@export var stand_offset := Vector3(-1.65,0.22,0.05)
