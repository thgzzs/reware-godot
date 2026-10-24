class_name WeaponActionCatalog
extends Resource
## Extend clip combinations in a Resource, without controller branches.
@export var melee_sets:Dictionary[String,PackedStringArray]={}
@export var long_reach := PackedStringArray(["baseballbat","golfclub","katana"])
@export var muzzle_offsets:Dictionary[String,Vector3]={}
@export var melee_tips:Dictionary[String,Vector3]={}
@export var animation_groups:Dictionary[String,String]={}
@export var ground_attacks:Dictionary[String,PackedStringArray]={
 "baseballbat":PackedStringArray(["WEAPON_bat_v"]),"golfclub":PackedStringArray(["WEAPON_bat_v"]),
 "nightstick":PackedStringArray(["WEAPON_bat_v"]),"hammer":PackedStringArray(["WEAPON_bat_v"]),
 "knife":PackedStringArray(["WEAPON_knife_part","WEAPON_knife_3"]),"screwdriver":PackedStringArray(["WEAPON_knife_part"]),
 "cleaver":PackedStringArray(["WEAPON_knife_part"]),"katana":PackedStringArray(["sword_3"]),
 "machete":PackedStringArray(["sword_3"]),"chainsaw":PackedStringArray(["WEAPON_csawlo"])}
@export var long_gun_pose:WeaponPoseProfile=preload("res://tuning/long_gun_pose.tres")
@export var two_hand_pistol_pose:WeaponPoseProfile=preload("res://tuning/two_hand_pistol_pose.tres")
