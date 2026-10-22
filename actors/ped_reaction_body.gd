class_name PedReactionBody
extends RigidBody3D
## Reusable dormant Jolt torso proxy. The same component serves player and NPC.
## Animation supplies articulation; this body exclusively owns impact trajectory.
var actor: CharacterMotor
var profile: PedImpactProfile = preload("res://tuning/ped_impact.tres")
var active := false
var age := 0.0
var vehicle_contacts := 0
var contact_ticks := 0
var supported := false
var stand_position := Vector3.ZERO
func configure(owner_actor: CharacterMotor) -> void:
 actor = owner_actor
 name = "ImpactBody"
 top_level = true
 mass = profile.mass_kg
 freeze = true
 collision_layer = 0
 collision_mask = 0
 continuous_cd = true
 contact_monitor = true
 max_contacts_reported = 8
 linear_damp = 0.12
 angular_damp = 1.8
 physics_material_override = PhysicsMaterial.new()
 physics_material_override.friction = profile.friction
 physics_material_override.bounce = profile.restitution
 var collider := CollisionShape3D.new()
 var shape := CapsuleShape3D.new()
 shape.radius = profile.radius
 shape.height = profile.torso_length
 collider.shape = shape
 collider.rotation.x = PI*0.5
 add_child(collider)
func launch(car: DriveVehicle, closing: float, direction: Vector3) -> void:
 if active: return
 active = true
 age = 0
 vehicle_contacts = 0
 contact_ticks = 0
 actor.collision_layer = 0
 actor.collision_mask = 0
 global_transform = Transform3D(Basis(Vector3.UP,actor.facing),actor.global_position+Vector3.UP*0.12)
 freeze = false
 sleeping = false
 collision_layer = 8
 collision_mask = 31
 add_collision_exception_with(actor)
 var reduced_mass := mass*car.mass/(mass+car.mass)
 var impulse := direction.normalized()*closing*reduced_mass*profile.transfer_fraction
 var lift := minf(profile.maximum_lift_speed,closing*profile.lift_per_speed)
 impulse += Vector3.UP*lift*mass
 linear_velocity = actor.velocity
 angular_velocity = direction.cross(Vector3.UP)*minf(2.4,closing*0.16)
 apply_central_impulse(impulse)
 car.apply_impulse(-impulse,global_position-car.global_position)
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
 if not active: return
 supported = false
 for i in range(state.get_contact_count()):
  var normal := state.transform.basis*state.get_contact_local_normal(i)
  if normal.dot(Vector3.UP)>0.45: supported = true
  if state.get_contact_collider_object(i) is DriveVehicle:
   vehicle_contacts += 1
 if state.get_contact_count()>0: contact_ticks += 1
func follow_pose(dt: float) -> void:
 age += dt
 actor.reaction_velocity = linear_velocity
 actor.velocity = linear_velocity
 actor.grounded = supported
 actor.global_position = global_position
 actor.visual.global_basis = global_basis
 if actor.reference_pose is SkinnedMotionVisual:
  var pose := actor.reference_pose as SkinnedMotionVisual
  pose.sample_pose(dt)
  var hip := pose.skeleton.find_bone("Pelvis")
  if hip>=0:
   actor.global_position += global_position-(pose.skeleton.global_transform*pose.skeleton.get_bone_global_pose(hip).origin)
func can_recover() -> bool:
 if age<profile.recovery_delay or linear_velocity.length()>profile.recovery_speed: return false
 var space := actor.get_world_3d().direct_space_state
 var ray := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*0.2,global_position-Vector3.UP*1.2,5,[get_rid(),actor.get_rid()])
 var floor_hit := space.intersect_ray(ray)
 if floor_hit.is_empty() or floor_hit.normal.y<actor.slope_cos(): return false
 stand_position = floor_hit.position+Vector3.UP*0.93
 var query := PhysicsShapeQueryParameters3D.new()
 query.shape = actor.normal_shape
 query.transform = Transform3D(Basis.IDENTITY,stand_position)
 query.collision_mask = 31
 query.exclude = [actor.get_rid(),get_rid()]
 query.margin = 0.005
 return space.intersect_shape(query,1).is_empty()
func deactivate() -> void:
 active = false
 freeze = true
 collision_layer = 0
 collision_mask = 0
 linear_velocity = Vector3.ZERO
 angular_velocity = Vector3.ZERO
 actor.visual.basis = Basis(Vector3.UP,actor.facing)
func receive_damage(amount: float, point: Vector3, direction: Vector3) -> void:
 actor.receive_damage(amount,point,direction)
