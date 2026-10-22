class_name ActionProfile
extends Resource
## Roles are resolved against the supplied library; missing gun blocks use IK.
@export var blend_seconds := 0.16
@export var reaction_floor_clearance := 0.01
@export var reaction_max_lift := 0.35
@export var reaction_settle_speed := 1.0
@export var upper_blend_rate := 12.0
@export var death_clips := PackedStringArray(["KO_shot_front","FALL_front","HIT_FLOOR"])
@export var knockdown_clips := PackedStringArray(["KO_skid_front","FALL_front"])
@export var getup_clips := PackedStringArray(["GETUP_front","GETUP"])
@export var aim_clips := PackedStringArray(["gun_stand","IDLE_armed"])
@export var fire_clips := PackedStringArray(["colt45_fire","pistol_fire"])
@export var reload_clips := PackedStringArray(["colt45_reload","pistol_reload"])
@export var upper_bones := PackedStringArray(["Spine1","Neck","Head","Bip01 L Clavicle","Bip01 R Clavicle","L UpperArm","L Forearm","L Hand","L Finger","R UpperArm","R Forearm","R Hand","R Finger"])
@export var allow_sprint_all_guns := true
@export var aim_movement_multiplier := 0.55
@export var knockdown_seconds := 1.2
@export var impact_damage_coefficient := 2.0
@export var impact_min_speed := 2.0
@export var impact_cooldown_seconds := 0.65
