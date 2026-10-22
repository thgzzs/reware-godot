class_name WeaponProfile
extends Resource
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
@export_range(1,16,1) var pellets := 1

