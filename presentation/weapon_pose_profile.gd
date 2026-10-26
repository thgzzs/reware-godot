class_name WeaponPoseProfile
extends Resource
## Replaceable arm presentation tuning, independent of ballistic weapon stats.
@export var reach := 0.53
@export var preserve_native_grip := false
@export var standing_hold_clips := PackedStringArray()
@export var standing_use_weapon_ready_pose := false
@export_range(0,0.8,0.01) var standing_lower_pitch := 0.30
@export_range(0.05,0.5,0.01) var standing_hold_blend_seconds := 0.22
@export var recoil_lift := 0.055
@export var grip_offset := Vector3(0.02,0,0)
@export var reload_grip := Vector3(0.10,-0.02,-0.30)
@export var reload_drop := 0.12
@export var support_reach := 0.20
@export var support_drop := 0.035
@export var magazine_offset := Vector3(-0.03,-0.04,0)
@export var magazine_travel := 0.16
@export_range(2,8,1) var solver_passes := 4
