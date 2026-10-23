class_name MeleeController
extends RefCounted
## Source DAT strike windows, one delivery per target/swing, animation-owned recovery.
var actor: CharacterMotor
var active := false
var time := 0.0
var duration := 0.5
var strike_start := 0.16
var strike_end := 0.27
var reach := 1.2
var radius := 0.4
var clip := "PUNCHR"
var combo := 0
var queued := false
var hit_ids := {}
var moves: Array[Dictionary] = []
var damage := 8.0
var strike_damage := 8.0
func configure(owner_actor: CharacterMotor) -> void: actor = owner_actor
func request() -> bool:
 if actor==null or not actor.can_use_weapon(): return false
 if actor.stance.crouched and not actor.stance.set_crouched(false): return false
 if active: queued = true;return false
 var move: Dictionary = moves[combo%moves.size()] if not moves.is_empty() else {}
 strike_damage = damage*maxf(1,float(move.get("damage_source",1)))
 combo += 1
 clip = String(move.get("animation_clip","PUNCHR"))
 strike_start = float(move.get("start_seconds",0.16))
 strike_end = float(move.get("end_seconds",0.27))
 radius = float(move.get("strike_radius_source",0.4))
 reach = 0.6*float(move.get("extend_reach_multiplier",1))+radius
 duration = maxf(strike_end+0.12,actor.reference_motion.duration(clip) if actor.reference_enabled else 0.5)
 active = true;time = 0;queued = false;hit_ids.clear()
 actor.actions.melee_active = true
 actor.actions.melee_clip = clip
 actor.actions.melee_time = 0
 return true
func cancel() -> void:
 active = false;queued=false
 if actor!=null: actor.actions.melee_active=false
func tick(cmd: GameplayCommand, dt: float) -> void:
 if not active: return
 if not actor.control_enabled or actor.health.health<=0 or not actor.grounded: cancel();return
 var before := time
 time += dt
 actor.actions.melee_time = time
 if cmd.fire and time>duration*0.5: queued = true
 if time>=strike_start and before<=strike_end: strike()
 if time>=duration:
  var next := queued and cmd.fire
  cancel()
  if next: request()
func strike() -> void:
 var forward := Basis(Vector3.UP,actor.facing)*Vector3.FORWARD
 var origin := actor.global_position+Vector3.UP*0.25
 var sphere := SphereShape3D.new()
 sphere.radius = radius
 var query := PhysicsShapeQueryParameters3D.new()
 query.shape = sphere
 query.transform = Transform3D(Basis.IDENTITY,origin+forward*reach)
 query.collision_mask = 15|32
 query.collide_with_areas = true
 query.exclude = [actor.get_rid(),actor.reaction_body.get_rid()]
 var space := actor.get_world_3d().direct_space_state
 for hit in space.intersect_shape(query,24):
  var receiver: Object = hit.collider
  if receiver is PedReactionBody: receiver=receiver.actor
  if receiver is VehicleHitRegion: receiver=receiver.car
  if hit_ids.has(receiver.get_instance_id()): continue
  var point: Vector3 = receiver.global_position
  var ray := PhysicsRayQueryParameters3D.create(origin,point,1,[actor.get_rid()])
  if not space.intersect_ray(ray).is_empty(): continue
  hit_ids[receiver.get_instance_id()] = true
  DamageEvent.deliver(receiver,DamageEvent.make(strike_damage*actor.attack_multiplier,point,forward,"melee",actor))
