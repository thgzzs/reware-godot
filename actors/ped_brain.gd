class_name PedBrain
extends Node
## Decisions only: the same motor, stance, weapon and spatial attack components as player.
var actor: CharacterMotor
var player: CharacterMotor
var waypoints := PackedVector3Array()
var destination := 0
var state := "wander"
var threat := Vector3.ZERO
var aggressor: CharacterMotor
var flee_left := 0.0
var fear := 50.0
var temper := 50.0
var flee_distance := 17.0
var relationships := {}
var attack_delay := 0.0
var pursuit_left := 0.0
func reset_decisions() -> void:
 state="wander";destination=0;threat=Vector3.ZERO;aggressor=null
 flee_left=0;attack_delay=0;pursuit_left=0
func _ready() -> void:
 if actor.reference_pose is SkinnedMotionVisual:actor.reference_pose.set_process(false)
 actor.attacked.connect(on_attacked)
func on_attacked(event: DamageEvent) -> void:
 if not event.source is CharacterMotor or event.source==actor: return
 aggressor=event.source
 threat=aggressor.global_position
 pursuit_left=12.0
 attack_delay=maxf(attack_delay,0.3)
 if event.kind=="melee" and temper+20>=fear:
  state="fight"
 else:
  state="flee";flee_left=5.0
func _physics_process(dt: float) -> void:
 var cmd := GameplayCommand.new()
 cmd.walk=true
 attack_delay=maxf(0,attack_delay-dt)
 pursuit_left=maxf(0,pursuit_left-dt)
 if actor.health.health<=0 or not actor.control_enabled:
  actor.weapon.advance(cmd,false,dt)
  actor.tick(cmd,actor.facing,dt)
  if actor.reference_pose is SkinnedMotionVisual and not actor.reaction_body.active:actor.reference_pose.sample_pose(dt)
  return
 var target := waypoints[destination] if not waypoints.is_empty() else actor.global_position
 if state=="fight":
  if not is_instance_valid(aggressor) or aggressor.health.health<=0 or pursuit_left<=0:
   state="wander";aggressor=null
  else:
   target=aggressor.global_position
   var distance:=Vector2(target.x-actor.global_position.x,target.z-actor.global_position.z).length()
   if distance<1.25:
    cmd.fire=attack_delay<=0 and aggressor.actions.life=="alive"
    if cmd.fire and not actor.weapon.melee.active: attack_delay=0.45
   elif distance<18:
    cmd.walk=distance<3.0
    cmd.move=Vector2(target.x-actor.global_position.x,target.z-actor.global_position.z).normalized()
   else: state="wander"
 elif state=="flee":
  flee_left-=dt
  target=actor.global_position+(actor.global_position-threat).normalized()*8
  cmd.walk=false
  cmd.sprint=fear>=65
  if flee_left<=0: state="wander"
 elif not waypoints.is_empty() and actor.global_position.distance_to(target)<0.8:
  destination=(destination+1)%waypoints.size()
 if state=="wander" and is_instance_valid(player) and relationships.get("avoid",[]).has("PLAYER1") and actor.global_position.distance_to(player.global_position)<1.2:
  target=actor.global_position+(actor.global_position-player.global_position).normalized()*2
 var direction:=target-actor.global_position
 direction.y=0
 direction=direction.normalized()
 if state!="fight":cmd.move=Vector2(direction.x,direction.z)
 var yaw:=atan2(-direction.x,-direction.z) if direction.length_squared()>0.001 else actor.facing
 # AI sets facing independently of the player's camera. Full-body attacks lock it.
 if state=="fight" and not actor.weapon.melee.active and not actor.actions.spatial_hit() and actor.grounded and actor.phase=="grounded": actor.facing=rotate_toward(actor.facing,yaw,actor.profile.turn_rate*dt)
 actor.weapon.advance(cmd,true,dt)
 actor.tick(cmd,0,dt)
 if cmd.fire and actor.weapon.cooldown<=0 and actor.can_use_weapon():
  if actor.weapon.melee.request(cmd):actor.weapon.cooldown=actor.weapon.profile.interval
 if actor.reference_pose is SkinnedMotionVisual and not actor.reaction_body.active:actor.reference_pose.sample_pose(dt)
 actor.weapon.melee.resolve_spatial_hits()
func hear_shot(position: Vector3) -> void:
 if relationships.get("threat",[]).has("GUN") and actor.global_position.distance_to(position)<flee_distance:
  threat=position;state="flee";flee_left=5.0
