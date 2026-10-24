class_name MeleeTargeting
extends RefCounted
static func ground_target(actor:CharacterMotor,reach:float) -> CharacterMotor:
 var best:CharacterMotor
 var distance:=reach*reach
 var forward:=Basis(Vector3.UP,actor.facing)*Vector3.FORWARD
 for candidate in actor.get_tree().get_nodes_in_group("combat_actors"):
  if candidate==actor or not candidate is CharacterMotor:continue
  if candidate.actions.life not in ["down","dead","dying"]:continue
  if not candidate.grounded and not candidate.reaction_body.rest.locked:continue
  var center:Vector3=candidate.corpse_hitbox.global_position if candidate.corpse_hitbox.active else candidate.reaction_body.global_position if candidate.reaction_body.active else candidate.global_position
  var delta:=center-actor.global_position;delta.y=0
  if absf(center.y-actor.global_position.y)>1.2:continue
  if delta.length_squared()>distance or (delta.length()>0.55 and delta.normalized().dot(forward)<0.05):continue
  var ray:=PhysicsRayQueryParameters3D.create(actor.global_position,center,1,[actor.get_rid(),candidate.get_rid()])
  if not actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
  best=candidate;distance=delta.length_squared()
 return best
