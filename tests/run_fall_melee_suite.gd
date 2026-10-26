extends SceneTree
var arena: Node3D
var results: Array[Dictionary]=[]
var failures:=0
var metrics:={}
func _initialize() -> void:run.call_deferred()
func check(label:String,passed:bool,measured:Variant=null) -> void:
 results.append({"name":label,"passed":passed,"measured":measured})
 if not passed:failures+=1
 print("PASS " if passed else "FAIL ",label," ",measured)
func frames(count:int,cmd:GameplayCommand=null) -> void:
 arena.injected_command=cmd if cmd!=null else GameplayCommand.new()
 for i in range(count):await physics_frame;await process_frame
func equip(id:String) -> void:
 for i in range(arena.weapon.inventory.size()):
  if arena.weapon.inventory[i].profile.id==id:arena.weapon.equip_slot(i);return
func drop(height:float) -> Dictionary:
 var actor:CharacterMotor=arena.actor
 actor.respawn(Vector3(-28,0.94+height,38))
 var event_start:=actor.fall.landing_events
 var fell:=false
 var saw_clip:=false
 var blocked_fire:=true
 for i in range(240):
  await frames(1)
  if actor.phase=="falling":
   fell=true
   saw_clip=saw_clip or actor.reference_motion.clip in ["FALL_fall","FALL_glide"]
   blocked_fire=blocked_fire and not actor.can_use_weapon()
  if actor.fall.landing_events>event_start:break
 return {"height":height,"health":actor.health.health,"speed":actor.fall.last_impact_speed,"damage":actor.fall.last_damage,"fell":fell,"native_clip":saw_clip,"blocked_fire":blocked_fire,"phase":actor.phase,"hard":actor.fall.hard_landing,"events":actor.fall.landing_events-event_start}
func run() -> void:
 arena=preload("res://scenes/arena.tscn").instantiate();arena.test_mode=true;arena.enable_vehicle_fixtures=false;root.add_child(arena)
 await frames(90)
 for brain in arena.ped_brains:brain.set_physics_process(false)
 var actor:CharacterMotor=arena.actor
 var gun:WeaponController=arena.weapon
 check("exact engine and Jolt remain pinned",Engine.get_version_info().minor==7 and Engine.get_version_info().patch==2 and ProjectSettings.get_setting("physics/3d/physics_engine")=="Jolt Physics")
 actor.respawn(Vector3(-28,0.94,38));await frames(30)
 var initial_jumps:=actor.jump_count
 var jump:=GameplayCommand.new();jump.jump=true
 await frames(1,jump);await frames(100)
 check("normal jumps remain safe and return to grounded control",actor.health.health==100 and actor.phase=="grounded" and actor.jump_count==initial_jumps+1,{"health":actor.health.health,"damage":actor.fall.last_damage})
 var short:=await drop(2.0)
 check("short drops do not apply fall damage",short.health==100 and short.events==1,short)
 var medium:=await drop(4.0)
 metrics.medium_drop=medium
 check("walking off a high ledge enters an explicit falling state",medium.fell and medium.native_clip and medium.blocked_fire,medium)
 check("moderate landing applies measured environmental damage",medium.damage>5 and medium.damage<35 and is_equal_approx(medium.health,100.0-medium.damage),medium)
 check("landing damage bypasses player combat-defense reduction",actor.health.defense_multiplier<1 and is_equal_approx(100.0-medium.health,medium.damage),actor.health.defense_multiplier)
 await frames(2)
 check("hard landings play the native landing recovery",actor.phase=="landing" and actor.reference_motion.clip=="FALL_land" and not actor.can_use_weapon(),actor.reference_motion.clip)
 var landed_health:=actor.health.health
 var count:=actor.fall.landing_events
 await frames(100)
 check("one landing cannot repeatedly damage a resting player",actor.health.health==landed_health and actor.fall.landing_events==count and actor.control_enabled and actor.phase=="grounded")
 var high:=await drop(7.0)
 metrics.high_drop=high
 check("larger drops cause more damage without automatic death",high.damage>medium.damage*2 and high.health>0 and high.health<medium.health,high)
 var lethal:=await drop(18.0)
 check("severe falls deplete health once into a grounded collapse clip",lethal.health==0 and actor.actions.life in ["dying","dead"] and actor.actions.life_clip==actor.actions.resolve(actor.fall.profile.death_clips) and actor.actions.life_clip!="FALL_collapse",lethal)
 actor.respawn(Vector3(-28,14,38));await frames(25)
 check("a long descent uses native falling presentation",actor.fall.falling and actor.phase=="falling",actor.reference_motion.clip)
 actor.reset_at(Vector3(-28,0.94,38));await frames(50)
 check("teleports reset accumulated fall evidence",actor.health.health==100 and actor.phase=="grounded" and actor.fall.last_damage==0)
 actor.respawn(Vector3(-28,150,38));await frames(125)
 var glide_time:=actor.reference_motion.time
 await frames(12)
 check("long falls loop their glide animation instead of freezing",actor.phase=="falling" and actor.reference_motion.clip=="FALL_glide" and not is_equal_approx(glide_time,actor.reference_motion.time),[glide_time,actor.reference_motion.time])
 actor.respawn(Vector3(-28,0.94,38));await frames(30)
 var default_fall:=actor.fall.profile
 actor.fall.profile=default_fall.duplicate();actor.fall.profile.damage_enabled=false
 var disabled:=await drop(7)
 check("fall damage can be disabled independently of fall animation",disabled.health==100 and disabled.fell and disabled.hard)
 actor.fall.profile=default_fall
 var ped:CharacterMotor=arena.pedestrians[0]
 ped.respawn(Vector3(-24,7.94,38))
 var ped_event:=ped.fall.landing_events
 for i in range(150):
  ped.weapon.advance(GameplayCommand.new(),true,1.0/60)
  ped.tick(GameplayCommand.new(),0,1.0/60)
  await frames(1)
  if ped.fall.landing_events>ped_event:break
 check("pedestrians use the same fall damage component with independent state",ped.fall!=actor.fall and ped.health.health>0 and ped.health.health<60 and is_equal_approx(ped.health.health,100.0-ped.fall.last_damage),ped.health.health)
 ped.respawn(Vector3(-25,0.94,24))
 # Moving support and slopes use relative normal closing speed, not world-Y speed.
 var support:=StaticBody3D.new();arena.add_child(support);support.constant_linear_velocity=Vector3.DOWN*8
 check("descending supports reduce relative landing impact",is_equal_approx(ActorFallState.closing_speed(Vector3.DOWN*12,Vector3.UP,support,Vector3.ZERO),4))
 support.constant_linear_velocity=Vector3.UP*3
 check("upward supports contribute relative landing impact",is_equal_approx(ActorFallState.closing_speed(Vector3.DOWN*12,Vector3.UP,support,Vector3.ZERO),15))
 support.queue_free()
 var slope:=Vector3(0,0.8,0.6)
 check("sliding along a slope is not counted as a fall impact",ActorFallState.closing_speed(Vector3(0,-6,8),slope,null,Vector3.ZERO)<0.001)
 # A real platform edge, rather than a spawn-only drop, drives the state machine.
 var ledge:=LabGeometry.box(arena,Vector3(4,0.3,4),Vector3(-28,4,30),Color.GRAY,true)
 actor.respawn(Vector3(-28,5.09,30));await frames(45)
 check("raised platform has stable support without damage",actor.grounded and actor.health.health==100)
 var walk_off:=GameplayCommand.new();walk_off.move=Vector2(0,-1)
 var saw_falling:=false
 for i in range(150):
  await frames(1,walk_off)
  saw_falling=saw_falling or actor.phase=="falling"
  if saw_falling and actor.grounded:break
 check("running off geometry produces a real falling and damaged landing loop",saw_falling and actor.health.health<100 and actor.health.health>0,{"health":actor.health.health,"at":actor.global_position})
 ledge.queue_free();await frames(2)
 # Moving melee retains locomotion legs and source-derived walk/run speed.
 for mode in ["walk","run","sprint"]:
  actor.respawn(Vector3(-28,0.94,38));actor.facing=0;actor.visual.rotation.y=0;await frames(30)
  equip("baseballbat");gun.cooldown=0;gun.melee.recovery=0
  var move:=GameplayCommand.new();move.move=Vector2(0,-1);move.walk=mode=="walk";move.sprint=mode=="sprint"
  await frames(60,move)
  var start:=actor.global_position
  await frames(36,move)
  var baseline:=actor.global_position.distance_to(start)
  start=actor.global_position;move.fire=true
  var mobile_ticks:=0
  var moving_leg:=false
  var visual:=actor.reference_pose as SkinnedMotionVisual
  var thigh:=visual.skeleton.find_bone("R Thigh")
  var first_pose:=visual.skeleton.get_bone_pose_rotation(thigh)
  for i in range(36):
   await frames(1,move)
   if actor.actions.melee_mobile:
    mobile_ticks+=1
    moving_leg=moving_leg or visual.skeleton.get_bone_pose_rotation(thigh).angle_to(first_pose)>0.1
  var distance:=actor.global_position.distance_to(start)
  check(mode+" melee retains normal stride speed without adding attack-root velocity",mobile_ticks>10 and distance>=baseline*0.85 and distance<=baseline*1.15,{"base_m":baseline,"attack_m":distance,"mobile_ticks":mobile_ticks})
  check(mode+" melee blends weapon swings over moving legs",moving_leg and actor.reference_motion.phase in ["start","move"] and actor.actions.melee_weight>0.8)
  move.fire=false;await frames(100,move)
  check(mode+" attack layer fades out without stopping locomotion",actor.actions.melee_weight==0 and not gun.melee.active and actor.reference_motion.phase=="move")
 for item in gun.inventory:
  if item.profile.kind!="melee" or item.profile.id=="unarmed":continue
  actor.respawn(Vector3(-28,0.94,38));actor.facing=0;actor.visual.rotation.y=0;await frames(20)
  equip(item.profile.id);gun.cooldown=0;gun.melee.recovery=0
  var travel:=GameplayCommand.new();travel.move=Vector2(0,-1)
  await frames(40,travel);travel.fire=true;await frames(12,travel)
  check("mobile melee is configured for "+item.profile.id,actor.actions.melee_mobile and actor.actions.melee_weight>0.9 and actor.reference_motion.phase=="move",gun.melee.clip)
 actor.respawn(Vector3(-28,0.94,38));await frames(30);equip("knife");gun.cooldown=0;gun.melee.recovery=0
 var attack:=GameplayCommand.new();attack.fire=true;attack.move=Vector2(0,-1)
 await frames(25,attack)
 var heading:=actor.facing;attack.move=Vector2(1,0);await frames(15,attack)
 check("running strikes can steer with bounded heading response",absf(angle_difference(actor.facing,heading))>0.15 and absf(angle_difference(actor.facing,heading))<=gun.melee.profile.steering_rate*0.3+0.05)
 # A stationary attack can start striding and stop again without a stale pose.
 actor.respawn(Vector3(-28,0.94,38));await frames(30);equip("katana");gun.cooldown=0;gun.melee.recovery=0;gun.melee.combo=0
 var transition_attack:=GameplayCommand.new();transition_attack.fire=true;await frames(1,transition_attack)
 var mobile_start:=actor.global_position
 transition_attack.fire=false;transition_attack.move=Vector2(0,-1);await frames(8,transition_attack)
 check("stationary strikes can transition into walking or running",actor.actions.melee_active and actor.actions.melee_mobile and actor.reference_motion.phase in ["start","move"] and actor.global_position.distance_to(mobile_start)>0.02,{"phase":actor.reference_motion.phase,"distance_m":actor.global_position.distance_to(mobile_start)})
 transition_attack.move=Vector2.ZERO;await frames(3,transition_attack)
 check("stopping a moving strike restores its full-body action",actor.actions.melee_active and not actor.actions.melee_mobile and actor.reference_motion.phase=="action")
 equip("colt45");await frames(20)
 check("weapon switching clears the mobile strike and fades its layer",not gun.melee.active and actor.actions.melee_weight==0)
 equip("knife");gun.cooldown=0;gun.melee.recovery=0
 # A target centered on the displayed moving weapon tip receives the real sweep.
 var target:=preload("res://scenes/target.tscn").instantiate();arena.add_child(target)
 actor.respawn(Vector3(-28,0.94,38));await frames(30);gun.cooldown=0;gun.melee.recovery=0
 attack.move=Vector2(0,-1);await frames(1,attack)
 attack.fire=false
 while gun.melee.active and gun.melee.time<gun.melee.strike_start-0.04:await frames(1,attack)
 target.global_position=gun.melee.posed_tip();target.get_node("CollisionShape3D").shape=SphereShape3D.new();target.get_node("CollisionShape3D").shape.radius=0.4
 await frames(12,attack)
 check("a moving native weapon sweep can damage a target",target.health<target.max_health,{"health":target.health,"hits":gun.melee.hit_ids.size()})
 target.queue_free()
 var wall:=LabGeometry.box(arena,Vector3(5,3,0.4),Vector3(-28,1.5,34),Color.GRAY,true)
 actor.respawn(Vector3(-28,0.94,37));await frames(30);gun.cooldown=0;gun.melee.recovery=0
 attack.fire=true;attack.move=Vector2(0,-1);await frames(100,attack)
 check("running attacks remain collision swept against world walls",actor.global_position.z>34.45 and actor.global_position.z<36,{"at":actor.global_position})
 wall.queue_free();await frames(2)
 # Falling during an attack cancels the strike and clears its mobile layer.
 actor.reset_at(Vector3(-28,6,38));await frames(20,attack)
 check("losing ground cancels moving melee and its upper layer",not gun.melee.active and actor.actions.melee_weight==0 and not actor.can_use_weapon())
 actor.respawn(Vector3(-28,0.94,38));await frames(40)
 check("falling and melee resume normally after respawn",actor.health.health==100 and actor.can_use_weapon() and not actor.fall.falling)
 var report:={"engine":Engine.get_version_info().string,"backend":"Jolt Physics","assertions":results.size(),"failures":failures,"results":results,"metrics":metrics,"reference_runtime_parity":false}
 var file:=FileAccess.open("res://tests/fall_melee_results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("RESULT fall/melee ",results.size()," / failures ",failures)
 arena.queue_free();await process_frame;quit(1 if failures else 0)
