class_name PedImpactProfile
extends Resource
## SI tuning. These values are provisional gameplay targets, not legacy unit conversions.
@export var minimum_speed := 2.0
@export var cooldown_seconds := 0.65
@export var mass_kg := 70.0
@export var radius := 0.29
@export var torso_length := 1.25
@export var friction := 0.55
@export var restitution := 0.05
@export var damage_speed_threshold := 2.0
@export var damage_coefficient := 0.65
@export var contact_rearm_gap := 0.25
@export var transfer_fraction := 0.72
@export var maximum_lift_speed := 4.8
@export var lift_per_speed := 0.45
@export var recovery_speed := 1.6
@export var recovery_delay := 2.0

@export var maximum_angular_speed := 2.2
@export var maximum_air_pitch := 0.9
@export var maximum_air_roll := 0.65
@export var air_angular_restore := 10.0
