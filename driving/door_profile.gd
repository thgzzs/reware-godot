class_name VehicleDoorProfile
extends Resource
@export var hinge_offsets := PackedVector3Array([Vector3(-0.91,0.1,-0.70),Vector3(0.91,0.1,-0.70)])
@export var panel_size := Vector3(0.06,0.65,1.25)
@export var panel_mass := 18.0
@export_range(20,85) var opening_degrees := 68.0
@export var motor_impulse := 2.5
@export var motor_gain := 6.0
@export var latch_radians := 0.025
@export var seat_offset := Vector3(-0.38,0.18,0.1)
@export var stand_offset := Vector3(-1.65,0.22,0.05)
