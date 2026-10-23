class_name CameraProfile
extends Resource
@export var follow_distance := 3.5
@export var on_foot_distances := PackedFloat32Array([2.25,3.5,4.9])
@export var vehicle_distances := PackedFloat32Array([4.8,6.5,8.5])
@export var bonnet_camera_offset := Vector3(0,0.65,-1.3)
@export var aim_distance := 3.0
@export var driving_distance := 7.5
@export var shoulder_offset := 0.60
@export var follow_rate := 12.0
@export var fov := 72.0
@export var aim_fov := 54.0
@export var mouse_sensitivity := 0.0025
@export var min_pitch := -0.8
@export var max_pitch := 1.1
@export var collision_radius := 0.20
