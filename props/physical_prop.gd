class_name PhysicalProp
extends RigidBody3D
@export var profile: PhysicalPropProfile = preload("res://tuning/trashcan.tres")
var hits := 0
func _ready() -> void:
 mass = profile.mass_kg
 collision_layer = 8
 collision_mask = 31
 continuous_cd = true
 physics_material_override = PhysicsMaterial.new()
 physics_material_override.friction = profile.friction
 physics_material_override.bounce = profile.bounce
 center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
 center_of_mass = Vector3.UP*profile.center_height
 var collider := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = profile.size
 collider.shape = box
 collider.position.y = profile.center_height
 add_child(collider)
func receive_hit(event: DamageEvent) -> void:
 hits += 1
 sleeping = false
 var direction := -event.normal if event.normal.length_squared()>0.1 else event.direction
 apply_impulse(direction*profile.bullet_impulse,event.point-global_position)
