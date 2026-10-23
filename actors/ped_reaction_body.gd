class_name PedReactionBody
extends RigidBody3D
## Reusable dormant Jolt torso proxy. The same component serves player and NPC.
## Animation supplies articulation; this body exclusively owns impact trajectory.
var actor: CharacterMotor
var profile: PedImpactProfile = preload("res://tuning/ped_impact.tres")
var active := false
var age := 0.0
var minimum_recovery_age := 0.0
var vehicle_contacts := 0
var contact_ticks := 0
var supported := false
var stand_position := Vector3.ZERO
var impact_contacts := {}
var previous_velocity := Vector3.ZERO
var previous_angular := Vector3.ZERO
var repeated_hits := 0
var maximum_contact_speed := 0.0
var last_contact_normal := Vector3.ZERO
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
func launch_velocity(at:Vector3, heading:float, initial:Vector3) -> void:
 active=true;age=0;vehicle_contacts=0;contact_ticks=0
 impact_contacts.clear()
 actor.collision_layer=0;actor.collision_mask=0
 global_transform=Transform3D(Basis(Vector3.UP,heading),at)
 freeze=false;sleeping=false
 collision_layer=8;collision_mask=31
 add_collision_exception_with(actor)
 linear_velocity=initial
 angular_velocity=Vector3(1.2,0,0.3)
 previous_velocity=initial
 previous_angular=angular_velocity
func launch(car: DriveVehicle, closing: float, direction: Vector3) -> void:
 if active: return
 impact_contacts.clear()
 impact_contacts[car.get_instance_id()] = {"seen":0.0,"hit":0.0,"armed":false}
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
 var bounds: Vector3 = (car.get_node("Hull").shape as BoxShape3D).size*0.5
 var contact := car.to_local(global_position).clamp(-bounds,bounds)
 car.apply_impulse(-impulse,car.global_basis*contact)
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
 if not active: return
 supported = false
 for i in range(state.get_contact_count()):
  var normal := state.get_contact_local_normal(i) # Jolt contact normal is already world-space.
  if normal.dot(Vector3.UP)>0.45: supported = true
  var other := state.get_contact_collider_object(i) as DriveVehicle
  if other!=null:
   vehicle_contacts += 1
   var id := other.get_instance_id()
   var record: Dictionary = impact_contacts.get(id,{"seen":-100.0,"hit":-100.0,"armed":true})
   var own_lever := state.get_contact_local_position(i)-state.transform.origin-state.center_of_mass
   var other_lever := state.get_contact_collider_position(i)-other.global_position-other.global_basis*other.center_of_mass
   var relative := other.damage.previous_velocity+other.damage.previous_angular.cross(other_lever)-(previous_velocity+previous_angular.cross(own_lever))
   var closing := maxf(0,relative.dot(normal))
   maximum_contact_speed = maxf(maximum_contact_speed,closing)
   last_contact_normal = normal
   if age-float(record.seen)>profile.contact_rearm_gap:
    record.armed = age-float(record.hit)>profile.cooldown_seconds
   if age>0.35 and record.armed and closing>profile.minimum_speed:
    var normal_fraction := closing/maxf(0.001,relative.length())
    var amount := pow(maxf(0,relative.length()-profile.damage_speed_threshold),2)*profile.damage_coefficient*normal_fraction
    var event := DamageEvent.make(amount,global_position,relative,"vehicle",other)
    event.relative_speed = closing
    actor.call_deferred("receive_hit",event)
    repeated_hits += 1
    record.hit = age
    record.armed = false
   record.seen = age
   impact_contacts[id] = record
 if state.get_contact_count()>0: contact_ticks += 1
 previous_velocity = state.linear_velocity
 previous_angular = state.angular_velocity
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
 if age<minimum_recovery_age:return false
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
 minimum_recovery_age=0
 freeze = true
 collision_layer = 0
 collision_mask = 0
 linear_velocity = Vector3.ZERO
 angular_velocity = Vector3.ZERO
 actor.visual.basis = Basis(Vector3.UP,actor.facing)
func receive_hit(event: DamageEvent) -> void: actor.receive_hit(event)
func receive_damage(amount: float, point: Vector3, direction: Vector3) -> void:
 actor.receive_damage(amount,point,direction)
