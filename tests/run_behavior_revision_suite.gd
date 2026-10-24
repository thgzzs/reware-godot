extends SceneTree
var arena:Node3D
var results:Array[Dictionary]=[]
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(label:String,ok:bool,data:Variant=null) -> void:
 results.append({"name":label,"passed":ok,"measured":data})
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label," ",data)
func frames(count:int,cmd:GameplayCommand=null) -> void:
 arena.injected_command=cmd if cmd!=null else GameplayCommand.new()
 for i in range(count):await physics_frame;await process_frame
func equip(id:String) -> void:
 for i in range(arena.weapon.inventory.size()):
  if arena.weapon.inventory[i].profile.id==id:arena.weapon.equip_slot(i);return
func reset(at:=Vector3(-28,0.94,38)) -> void:
 arena.weapon.melee.cancel();arena.actor.respawn(at);arena.actor.facing=0;arena.actor.visual.rotation.y=0;arena.rig.yaw=0;arena.rig.pitch=0
func board(car:DriveVehicle) -> void:
 reset(car.approach_position(0));car.reserve_seat(arena.actor,0);car.commit_seat(arena.actor,0);arena.actor.set_embarked(true)
 arena.transition.vehicle=car;arena.transition.seat_index=0;arena.transition.state="driving"
func run() -> void:
 arena=preload("res://scenes/arena.tscn").instantiate();arena.test_mode=true;root.add_child(arena);await frames(150)
 for brain in arena.ped_brains:brain.set_physics_process(false)
 var actor:CharacterMotor=arena.actor
 var gun:WeaponController=arena.weapon
 var car:DriveVehicle=arena.vehicle
 var transition:VehicleTransition=arena.transition
 check("exact stable engine and Jolt",Engine.get_version_info().minor==7 and Engine.get_version_info().patch==2 and Engine.get_version_info().status=="stable" and ProjectSettings.get_setting("physics/3d/physics_engine")=="Jolt Physics")
 reset(Vector3(-28,1.59,38));var events:=actor.landing.events
 var move:=GameplayCommand.new();move.move=Vector2(0,-1)
 var landing_seen:=false;var lock_seen:=false;var landing_motion:=0.0
 for i in range(80):
  var before:=actor.global_position
  await frames(1,move)
  if actor.landing.weight>0:
   landing_seen=true;lock_seen=lock_seen or actor.phase=="landing";landing_motion+=actor.global_position.distance_to(before)
 check("low drop plays a visible landing without locking locomotion",landing_seen and not lock_seen and actor.landing.events>events and landing_motion>0.05,{"visible":landing_seen,"locked":lock_seen,"motion":landing_motion})
 reset();await frames(35)
 var hit:=DamageEvent.make(12,actor.global_position,Vector3.BACK,"bullet")
 var hit_at:=actor.global_position
 actor.receive_hit(hit);await frames(4)
 check("directional hit owns a timed full upper reaction",actor.actions.reaction_left>0 and actor.actions.reaction_time>0 and not actor.actions.upper_allowed,{"clip":actor.actions.reaction_clip,"time":actor.actions.reaction_time})
 var hit_pose:SkinnedMotionVisual=actor.reference_pose
 var hit_floor:=hit_pose.global_position.y+hit_pose.skin_minimum_y()
 check("stationary hit translation keeps a foot near the floor",hit_floor>= -0.06 and hit_floor<0.08,hit_floor)
 check("hits apply collision-swept physical stagger",actor.global_position.distance_to(hit_at)>0.001,actor.global_position.distance_to(hit_at))
 await frames(55);check("hit recovery restores upper control",actor.actions.reaction_left==0)
 reset();await frames(30)
 move.sprint=true;await frames(100,move)
 move.sprint=false;move.walk=true;await frames(1,move)
 var weight:=actor.reference_motion.sprint_weight
 check("releasing sprint retains a decaying stride contribution",weight>0.8,weight)
 await frames(12,move);var mid:=actor.reference_motion.sprint_weight
 check("sprint to walk blends over multiple frames",mid>0 and mid<weight,mid)
 await frames(35,move);check("walk transition finishes",actor.reference_motion.sprint_weight==0)
 reset();await frames(30)
 var pose:SkinnedMotionVisual=actor.reference_pose
 var count_before:=pose.sample_count
 await frames(30)
 check("native presentation advances once per simulation tick",pose.sample_count-count_before==30,pose.sample_count-count_before)
 var aim:=GameplayCommand.new();aim.aim=true
 for id in ["m4","ruger","shotgun","spas12","stubby"]:
  equip(id);await frames(45,aim)
  var hand:=pose.skeleton.get_bone_global_pose(pose.skeleton.find_bone("R Hand"))
  var direction:Vector3=(pose.skeleton.to_local(actor.actions.aim_target)-hand.origin).normalized()
  check(id+" preserves native two-handed pose and centers aim",gun.profile.pose.preserve_native_grip and hand.basis.x.normalized().angle_to(direction)<0.09,{"error_rad":hand.basis.x.normalized().angle_to(direction),"clip":actor.actions.upper_clip()})
 check("old crouch is selected without replacing the animation archive",is_equal_approx(actor.reference_motion.library.get_animation("WEAPON_crouch").length,0.5),actor.reference_motion.library.get_animation("WEAPON_crouch").length)
 reset();await frames(30);equip("unarmed")
 var punch:=GameplayCommand.new();punch.fire=true;punch.move=Vector2(0,-1)
 var fixed:=true
 for i in range(7):
  gun.melee.cancel();gun.melee.recovery=0
  fixed=fixed and gun.melee.request(punch) and gun.melee.clip=="PUNCHR" and gun.melee.strike_bone=="R Hand"
 check("all moving bare combos use one punch and never kick",fixed)
 gun.melee.cancel();reset();await frames(30)
 var ped:CharacterMotor=arena.pedestrians[0]
 ped.respawn(actor.global_position+Vector3(0,0,-0.6))
 ped.receive_hit(DamageEvent.make(1000,ped.global_position,Vector3.FORWARD,"bullet"))
 for i in range(160):ped.tick(GameplayCommand.new(),0,1.0/60);await frames(1)
 check("settled dead pedestrians retire solid collision",ped.corpse_retired and not ped.reaction_body.active and ped.reaction_body.freeze and ped.collision_layer==0 and ped.corpse_hitbox.active,{"retired":ped.corpse_retired,"body":ped.reaction_body.active})
 check("corpse is a query-only melee target",ped.corpse_hitbox.collision_layer==32 and ped.corpse_hitbox.collision_mask==0)
 actor.global_position=ped.global_position+Vector3(0,0,0.45);actor.facing=0;actor.grounded=true;actor.phase="grounded"
 check("ground detection selects nearby prone body",MeleeTargeting.ground_target(actor,1.35)==ped)
 gun.melee.recovery=0;check("unarmed floor attack selects native ground kick",gun.melee.request() and gun.melee.clip=="KICK_floor" and gun.melee.ground_attack,gun.melee.clip)
 await frames(45)
 check("native ground kick sweep reaches the corpse proxy",ped.actions.floor_hit_left>0,ped.actions.floor_hit_clip)
 gun.melee.cancel();equip("baseballbat");gun.melee.recovery=0
 check("weapon floor attack selects downward swing",gun.melee.request() and gun.melee.clip=="WEAPON_bat_v" and not actor.actions.melee_mobile,gun.melee.clip)
 ped.receive_hit(DamageEvent.make(5,ped.global_position,Vector3.DOWN,"melee",actor))
 check("floor hits animate without reactivating corpse physics",ped.actions.floor_hit_left>0 and not ped.reaction_body.active)
 gun.melee.cancel();ped.respawn(Vector3(-25,0.94,24));check("respawn clears retired hitbox",not ped.corpse_retired and not ped.corpse_hitbox.active)
 car.freeze=true;car.reset_at(Vector3(0,0.8,20));await frames(4)
 check("Idaho exposes exactly two seats and two doors",car.seating.definitions.size()==2 and car.doors.size()==2,[car.seating.definitions.size(),car.doors.size()])
 reset(car.approach_position(0)+Vector3.LEFT*2.1);await frames(30)
 check("entry rejects a distant door even inside old center radius",not transition.request_enter(car),transition.message)
 reset(car.approach_position(0)+Vector3.LEFT*1.25);await frames(30)
 var accepted:=transition.request_enter(car)
 check("nearby valid door reserves an approach",accepted,transition.message)
 if accepted:
  check("approach runs until the final alignment distance",not transition.approach_command().walk)
  for i in range(500):
   await frames(1)
   if transition.state not in ["approaching","entering","shuffling"]:break
  check("calibrated door approach reaches driver ownership",transition.state=="driving" and car.driver==actor,{"state":transition.state,"message":transition.message})
  if transition.state=="driving":
   var pelvis:=pose.skeleton.global_transform*pose.skeleton.get_bone_global_pose(pose.skeleton.find_bone("Pelvis"))
   check("seated pelvis matches model seat anchor",pelvis.origin.distance_to(car.seat_position(0))<0.03,pelvis.origin.distance_to(car.seat_position(0)))
 transition.recover();await frames(5)
 car.freeze=false;car.damage.repair();car.reset_at(Vector3(24,0.8,5));await frames(90)
 var wall:=LabGeometry.box(arena,Vector3(6,3,0.4),Vector3(24,1.5,-3),Color.GRAY,true);await frames(3)
 car.brake=0;car.linear_velocity=Vector3(0,0,-14);await frames(70)
 check("real frontal Jolt collision damages bonnet",car.parts.parts.has("bonnet") and car.parts.parts.bonnet.health<car.parts.profile.durability,car.parts.parts.bonnet)
 wall.queue_free();await frames(3)
 var bike:DriveVehicle
 for child in arena.get_children():
  if child is DriveVehicle and child.kind=="bike":bike=child;break
 check("bike fixtures exist",bike!=null)
 if bike!=null:
  bike.reset_at(Vector3(-10,0.6,38));bike.reset_transform.basis=Basis(Vector3.FORWARD,1.2);bike.freeze=false;await frames(120)
  check("unoccupied bike falls under Jolt without rider balancing",bike.bike.fallen(),bike.global_basis.y.dot(Vector3.UP))
  reset(bike.approach_position(0,0));await frames(30)
  print("BIKE ENTRY ",actor.global_position," target ",bike.approach_position(0,0)," phase ",actor.phase)
  accepted=transition.request_enter(bike)
  var lift_seen:=false;var lifted:=false
  if accepted:
   for i in range(650):
    await frames(1)
    lift_seen=lift_seen or transition.state=="lifting"
    lifted=lifted or (lift_seen and bike.global_basis.y.dot(Vector3.UP)>0.9)
    if transition.state in ["on_foot","driving"]:break
  check("fallen bike uses pickup animation and physical lift",accepted and lift_seen and lifted,{"state":transition.state,"message":transition.message,"up":bike.global_basis.y.dot(Vector3.UP)})
  check("pickup resumes mount into exclusive driver control",transition.state=="driving" and bike.driver==actor,transition.state)
  if transition.state!="driving":
   transition.recover();bike.reset_at(Vector3(-10,0.6,38));bike.global_basis=Basis.IDENTITY;board(bike)
  var reverse:=GameplayCommand.new();reverse.move=Vector2(0,1)
  for i in range(4):
   await frames(30,reverse)
   print("REVERSE ",bike.speed," pos ",bike.global_position," up ",bike.global_basis.y," touching ",bike.wheels[0].touching," ",bike.wheels[2].touching," load ",bike.wheels[0].normal_load," brake ",bike.brake," throttle ",bike.throttle," driver ",bike.driver)
  check("bike reverse uses pushing clip",actor.reference_motion.clip.ends_with("_pushes"),actor.reference_motion.clip)
  check("bike reverse is capped at walking speed",bike.speed< -0.15 and bike.speed> -1.4,bike.speed)
  check("bike reverse releases steering lean",absf(bike.bike.lean)<0.05,bike.bike.lean)
  transition.recover();bike.reset_at(Vector3(-10,0.6,38));bike.reset_transform.basis=Basis(Vector3.FORWARD,1.2);await frames(120)
  reset(bike.approach_position(0,0));await frames(30)
  var reserve:=transition.request_enter(bike)
  if reserve:transition.begin_lift();await frames(12);transition.cancel_lift("test cancel")
  check("cancelling pickup releases reservation and standing control",reserve and transition.state=="on_foot" and bike.reservation==null and actor.control_enabled and actor.collision_layer!=0 and not bike.bike.lifting)
  bike.reset_at(Vector3(-10,0.65,38));bike.global_basis=Basis.IDENTITY;board(bike);await frames(12)
  var bike_wall:=LabGeometry.box(arena,Vector3(6,3,0.4),Vector3(-10,1.5,32),Color.GRAY,true);await frames(3)
  bike.brake=0;bike.linear_velocity=Vector3(0,0,-14)
  var ejected:=false;var crash_speed:=0.0;var crash_clip:="";var native_crash:=false
  for i in range(90):
   await frames(1)
   ejected=ejected or transition.state=="on_foot"
   if actor.reaction_body.active:crash_speed=maxf(crash_speed,actor.reaction_body.linear_velocity.length());crash_clip=actor.actions.life_clip;native_crash=native_crash or crash_clip in ["BIKE_fall_off","BIKE_fallR"]
  check("wall impact ejects rider and releases bike ownership",ejected and bike.driver==null and actor.actions.life in ["down","getting_up","dying","dead"],{"state":transition.state,"life":actor.actions.life,"velocity":actor.reaction_body.linear_velocity})
  check("crash inherits momentum and native bike fall presentation",crash_speed>3 and native_crash,{"peak_speed":crash_speed,"clip":crash_clip})
  bike_wall.queue_free()
 var report:={"engine":Engine.get_version_info().string,"backend":"Jolt Physics","assertions":results.size(),"failures":failures,"results":results,"reference_runtime_parity":false}
 var file:=FileAccess.open("res://tests/behavior_revision_results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("RESULT behavior revision ",results.size()," / failures ",failures)
 arena.queue_free();await process_frame;quit(1 if failures else 0)
