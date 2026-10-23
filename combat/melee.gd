class_name MeleeController
extends RefCounted
## Clip-driven swept spatial attacks. No duplicate damage through body/part proxies.
var actor: CharacterMotor
var profile: MeleeProfile = preload("res://tuning/melee.tres")
var active := false
var time := 0.0
var previous_time := 0.0
var duration := 0.5
var strike_start := 0.16
var strike_end := 0.27
var reach := 1.2
var radius := 0.24
var clip := "FIGHTpunch"
var strike_bone := "R Hand"
var combo := 0
var queued := false
var hit_ids := {}
var moves: Array[Dictionary] = []
var damage := 8.0
var strike_damage := 8.0
var recovery := 0.0
var previous_tip := Vector3.ZERO
var tip_ready := false
var sphere := SphereShape3D.new()
var query := PhysicsShapeQueryParameters3D.new()
var ignored: Array[RID] = []
func configure(owner_actor: CharacterMotor) -> void:
 actor = owner_actor
 query.shape = sphere
 query.collision_mask = 15|32
 query.collide_with_areas = true
func request() -> bool:
 if actor==null or not actor.can_use_weapon() or recovery>0: return false
 if actor.stance.crouched and not actor.stance.set_crouched(false): return false
 var gun := actor.weapon.profile
 var bare := gun.id in ["unarmed","brassknuckle"]
 var choices := gun.melee_clips if not bare else profile.combo_clips
 if choices.is_empty(): return false
 var selected := combo%choices.size()
 clip = actor.actions.resolve(PackedStringArray([choices[selected]]))
 if clip.is_empty(): clip = "PUNCHR"
 var move: Dictionary = moves[selected%moves.size()] if not moves.is_empty() else {}
 if bare:
  var move_damage := maxf(1,float(move.get("damage_source",1)))
  # Source: (moveDamage * (2 or 3) + 1) * 3; player attack stat is NOT applied.
  strike_damage = (move_damage*(2 if combo%2==0 else 3)+1)*3*profile.damage_scale
  if actor.archetype!="STAT_PLAYER": strike_damage *= actor.attack_multiplier
  if gun.id=="brassknuckle": strike_damage *= 1.5
  strike_bone = profile.strike_bones[selected%profile.strike_bones.size()]
 else:
  strike_damage = gun.damage*profile.weapon_damage_scale
  strike_bone = "R Hand"
 combo += 1
 duration = maxf(0.25,actor.reference_motion.duration(clip)) if actor.reference_enabled else 0.5
 if bare and not move.is_empty():
  strike_start = minf(duration*0.65,float(move.get("start_seconds",duration*0.3)))
  strike_end = minf(duration*0.85,float(move.get("end_seconds",duration*0.65)))
 else:
  strike_start = duration*gun.melee_strike_start
  strike_end = duration*gun.melee_strike_end
 radius = profile.strike_radius if bare else gun.melee_radius
 reach = profile.hand_reach if bare else gun.melee_reach
 active = true;time = 0;previous_time=0;queued = false;hit_ids.clear();tip_ready=false
 ignored = [actor.get_rid(),actor.reaction_body.get_rid()]
 query.exclude = ignored
 actor.actions.melee_active = true
 actor.actions.melee_clip = clip
 actor.actions.melee_time = 0
 return true
func cancel() -> void:
 if active: recovery = profile.minimum_recovery
 active = false;queued=false;tip_ready=false
 if actor!=null: actor.actions.melee_active=false
func tick(cmd: GameplayCommand, dt: float) -> void:
 recovery = maxf(0,recovery-dt)
 if not active: return
 if not actor.control_enabled or actor.health.health<=0 or not actor.grounded: cancel();return
 previous_time = time
 time = minf(duration,time+dt)
 actor.actions.melee_time = time
 if time>=duration: cancel()
func root_delta() -> Vector3:
 if not active or not actor.reference_enabled: return Vector3.ZERO
 var delta := actor.reference_motion.segment(clip,previous_time,time)*profile.root_motion_scale
 delta.y = 0
 return delta
func strike_tip(at: float) -> Vector3:
 if actor.reference_pose is SkinnedMotionVisual:
  var visual := actor.reference_pose as SkinnedMotionVisual
  var bone := visual.skeleton.find_bone(strike_bone)
  if bone>=0:
   var transform := Transform3D.IDENTITY
   var chain: Array[int] = []
   var index := bone
   while index>=0:
    chain.push_front(index);index=visual.skeleton.get_bone_parent(index)
   for i in chain:
    transform *= Transform3D(Basis(visual.rotation_at(clip,at,i)),visual.position_at(clip,at,i))
   if actor.weapon.profile.id not in ["unarmed","brassknuckle"]:
    return visual.skeleton.global_transform*(transform*actor.weapon.profile.melee_tip)
   var point := visual.skeleton.global_transform*transform.origin
   return point+Basis(Vector3.UP,actor.facing)*Vector3.FORWARD*reach
 return actor.global_position+Vector3.UP*0.2+Basis(Vector3.UP,actor.facing)*Vector3.FORWARD*(0.65+reach)
func resolve_spatial_hits() -> void:
 if not active: return
 var tip := strike_tip(time)
 if not tip_ready: previous_tip = strike_tip(previous_time);tip_ready=true
 if time>=strike_start and previous_time<=strike_end:
  var first := strike_tip(maxf(previous_time,strike_start))
  var last := strike_tip(minf(time,strike_end))
  var count := clampi(ceili(first.distance_to(last)/maxf(0.04,radius*0.65)),1,8)
  for i in range(count+1): strike_at(first.lerp(last,float(i)/count))
 previous_tip=tip
func strike() -> void: strike_at(strike_tip(time))
func strike_at(point: Vector3) -> void:
 sphere.radius = radius
 query.transform = Transform3D(Basis.IDENTITY,point)
 var space := actor.get_world_3d().direct_space_state
 for hit in space.intersect_shape(query,32):
  var receiver: Object = hit.collider
  var identity: Object = receiver
  if receiver is PedReactionBody: identity=receiver.actor;receiver=identity
  if receiver is OccupantHitbox: identity=receiver.actor
  if receiver is VehicleHitRegion: identity=receiver.car
  if identity==actor or hit_ids.has(identity.get_instance_id()): continue
  if not receiver.has_method("receive_hit") and not receiver.has_method("receive_damage"): continue
  var forward := Basis(Vector3.UP,actor.facing)*Vector3.FORWARD
  var origin := actor.global_position+Vector3.UP*0.25
  var ray := PhysicsRayQueryParameters3D.create(origin,point,1,ignored)
  if not space.intersect_ray(ray).is_empty(): continue
  hit_ids[identity.get_instance_id()] = true
  DamageEvent.deliver(receiver,DamageEvent.make(strike_damage,point,forward,"melee",actor))
