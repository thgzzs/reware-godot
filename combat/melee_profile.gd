class_name MeleeProfile
extends Resource
## Intentional balance controls around source strike timing/damage semantics.
@export var damage_scale := 0.65
@export var weapon_damage_scale := 0.8
@export var root_motion_scale := 0.65
@export var shuffle_speed := 0.75
@export var allow_mobile_attacks := true
@export var steering_rate := 2.8
@export var minimum_recovery := 0.18
@export var strike_radius := 0.24
@export var hand_reach := 0.35
@export var weapon_reach := 0.55
@export var combo_clips := PackedStringArray(["FIGHTpunch","FIGHTjab","FIGHTLhook","FIGHTlngkck"])
@export var strike_bones := PackedStringArray(["R Hand","R Hand","L Hand","R Foot"])
