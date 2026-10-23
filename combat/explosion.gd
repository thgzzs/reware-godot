class_name GameplayExplosion
extends RefCounted
## Bounded physical query, line-of-sight damage and one delivery per entity.
static func emit(world: Node3D, at: Vector3, radius: float, damage: float, impulse: float, source: Node = null) -> int:
 var shape := SphereShape3D.new()
 shape.radius = radius
 var query := PhysicsShapeQueryParameters3D.new()
 query.shape = shape
 query.transform = Transform3D(Basis.IDENTITY,at)
 query.collision_mask = 15
 query.collide_with_areas = false
 var space := world.get_world_3d().direct_space_state
 var seen := {}
 var count := 0
 for hit in space.intersect_shape(query,128):
  var receiver: Node3D = hit.collider
  if receiver is PedReactionBody: receiver = receiver.actor
  if receiver==source or seen.has(receiver.get_instance_id()): continue
  seen[receiver.get_instance_id()] = true
  var toward := receiver.global_position-at
  var fraction := clampf(1.0-toward.length()/radius,0,1)
  if fraction<=0: continue
  var ray := PhysicsRayQueryParameters3D.create(at,receiver.global_position,1)
  if not space.intersect_ray(ray).is_empty(): continue
  DamageEvent.deliver(receiver,DamageEvent.make(damage*fraction,receiver.global_position,toward,"explosion",source))
  var physical: RigidBody3D = receiver if receiver is RigidBody3D else null
  if receiver is CharacterMotor and receiver.reaction_body.active: physical = receiver.reaction_body
  if physical!=null: physical.apply_central_impulse((toward.normalized()+Vector3.UP*0.35).normalized()*impulse*fraction)
  count += 1
 var effect := ExplosionVisual.new()
 world.get_tree().current_scene.add_child(effect) if world.get_tree().current_scene!=null else world.get_parent().add_child(effect)
 effect.global_position = at
 return count
