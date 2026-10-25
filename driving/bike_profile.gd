class_name BikeProfile
extends Resource
@export var balance_strength := 36.0
@export var balance_damping := 12.0
@export var maximum_lean := 0.48
@export var pickup_up_dot := 0.85
@export var parked_lean := 0.05
@export var lateral_acceleration := 8.0
@export var suspension_length := 0.45
@export var static_sag := 0.16
@export var wheel_radius := 0.30
@export var reverse_speed := 0.9
@export var reverse_acceleration := 0.9
@export var lean_return_rate := 3.5
@export var coast_yaw_damping := 1.5
@export var crash_min_speed := 6.5
@export var crash_damage_scale := 3.0
@export var fall_up_dot := 0.40
@export var rider_max_angular_speed := 5.0
@export var lift_release_seconds := 0.4667
@export var lift_timeout := 4.5
@export var lift_strength := 160.0
@export var lift_damping := 26.0

@export var standing_release_speed := 1.25
@export var standing_up_dot := 0.82
@export var wheel_support_up_dot := 0.68
@export var center_of_mass := Vector3(0,0.12,0)

@export var lift_weight_support := 0.80
@export var lift_max_angular_acceleration := 120.0
## reVC action aliases are opposite the literal L/R clip suffixes.
@export var pickup_clips := PackedStringArray(["BIKE_pickupR","BIKE_pickupL"])
@export var pullup_clips := PackedStringArray(["BIKE_pullupR","BIKE_pullupL"])
