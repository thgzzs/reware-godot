class_name PhysicalPropProfile
extends Resource
@export var mass_kg := 18.0
@export var size := Vector3(0.78,1.04,0.88)
@export var center_height := 0.52
@export var friction := 0.5
@export var bounce := 0.08
@export var bullet_impulse := 200.0 # Weapon.cpp object impulse 4.0 multiplied by normalized 50 Hz.
