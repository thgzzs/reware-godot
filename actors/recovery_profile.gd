class_name PedRecoveryProfile
extends Resource
## Recovery uses physical impulses and clear supported routes; no rescue teleport.
@export var probe_interval := 0.12
@export var minimum_floor_dot := 0.68
@export var maximum_height_change := 0.32
@export var search_radii := PackedFloat32Array([0.6,1.0,1.45,1.9])
@export var directions := 12
@export var path_step := 0.16
@export var separation_speed := 1.2
@export var separation_acceleration := 4.0
@export var maximum_bike_speed := 2.5
