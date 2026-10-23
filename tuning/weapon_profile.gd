class_name WeaponProfile
extends Resource
@export var pose: WeaponPoseProfile = preload("res://tuning/weapon_pose.tres")
@export var id := "colt45"
@export_enum("hitscan","melee") var kind := "hitscan"
@export var model_scene := "res://assets/converted/models/colt45.scn"
@export var source_model_id := -1
@export var two_handed := false
@export var display_name := "LAB / 9"
@export var interval := 0.20
@export var reload_seconds := 1.20
@export var magazine_size := 12
@export var reserve_ammo := 240
@export var damage := 25.0
@export var range_meters := 100.0
@export var spread_radians := 0.008
@export var recoil_radians := 0.012
@export var animation_group := "colt45"
@export var heavy := false
@export var native_fire_recovery := 0.0
@export var fire_frame_seconds := 0.0
@export var melee_clips := PackedStringArray(["FIGHTpunch","FIGHTjab","FIGHTLhook","FIGHTlngkck"])
@export var muzzle_local := Vector3(0.2,0.08,-0.03)
@export var melee_tip := Vector3(0.08,0.65,0)
@export var melee_reach := 0.55
@export var melee_radius := 0.24
@export var melee_strike_start := 0.3
@export var melee_strike_end := 0.7
@export_range(1,16,1) var pellets := 1

