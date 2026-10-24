extends SceneTree
var arena:Node3D
var results:Array[Dictionary]=[]
var failures:=0
var metrics:={}
func _initialize() -> void:run.call_deferred()
func check(label:String, condition:bool, measured:Variant=null) -> void:
 results.append({"name":label,"passed":condition,"measured":measured})
 if not condition:failures+=1
 print("PASS " if condition else "FAIL ",label," ",measured)
func frames(count:int,cmd:GameplayCommand=null) -> void:
 arena.injected_command=cmd if cmd!=null else GameplayCommand.new()
 for i in range(count):await physics_frame;await process_frame
func equip(id:String) -> void:
 for i in range(arena.weapon.inventory.size()):
  if arena.weapon.inventory[i].profile.id==id:arena.weapon.equip_slot(i);return
func reset_actor(at:Vector3) -> void:
 arena.weapon.melee.cancel();arena.actor.respawn(at)
 arena.actor.facing=0;arena.actor.visual.rotation.y=0
func board(car:DriveVehicle,seat:=0) -> void:
 arena.actor.respawn(car.approach_position(seat))
 car.reserve_seat(arena.actor,seat);car.commit_seat(arena.actor,seat)
 arena.actor.set_embarked(true)
 arena.transition.vehicle=car;arena.transition.seat_index=seat
 arena.transition.escape_mode=false
 arena.transition.state="driving" if seat==0 else "passenger"
func run() -> void:
 arena=preload("res://scenes/arena.tscn").instantiate();arena.test_mode=true;root.add_child(arena)
 await frames(150)
 for brain in arena.ped_brains:brain.set_physics_process(false)
 var actor:CharacterMotor=arena.actor
 var car:DriveVehicle=arena.vehicle
 var gun:WeaponController=arena.weapon
 var transition:VehicleTransition=arena.transition
 check("exact Godot 4.7.2 Stable and Jolt backend",Engine.get_version_info().major==4 and Engine.get_version_info().minor==7 and Engine.get_version_info().patch==2 and Engine.get_version_info().status=="stable" and ProjectSettings.get_setting("physics/3d/physics_engine")=="Jolt Physics")
 check("24 supported weapon entries have exact imported models",gun.inventory.size()==24,gun.inventory.size())
 var exact:=true
 var melee_count:=0
 for item in gun.inventory:
  var p:WeaponProfile=item.profile
  if p.kind=="melee":melee_count+=1
  if p.id!="unarmed" and (not ResourceLoader.exists(p.model_scene) or not p.model_scene.ends_with("/"+p.id+".scn")):exact=false
 check("no firearm or melee model is substituted",exact)
 check("melee arsenal is reusable through Resource clip lists",melee_count==12,melee_count)
 var pose:SkinnedMotionVisual=actor.reference_pose
 var hand:=pose.skeleton.find_bone("R Hand")
 var forearm:=pose.skeleton.find_bone("R Forearm")
 check("space-prefixed Colt arm tracks bind by original bone ID",pose.binding("colt45_fire")[hand][0]>=0 and pose.binding("colt45_fire")[forearm][0]>=0)
 check("LCS bike leg and hand tracks bind to original rig",pose.binding("BIKEs_Ride")[hand][0]>=0 and pose.binding("BIKEs_Ride")[pose.skeleton.find_bone("R Thigh")][0]>=0)
 reset_actor(Vector3(-24,0.94,38));await frames(40)
 arena.rig.yaw=0.65;arena.rig.pitch=0
 var walk:=GameplayCommand.new();walk.walk=true;walk.move=Vector2(1,0)
 await frames(75,walk)
 var before_facing:=actor.facing
 var before_shots:=gun.shots
 walk.fire=true
 await frames(40,walk)
 check("hip firing raises arm without steering walking body to camera",absf(angle_difference(actor.facing,before_facing))<0.03 and gun.shots>before_shots,{"facing_before":before_facing,"facing_after":actor.facing,"shots":gun.shots-before_shots})
 check("one-handed hip fire retains base pose on left arm",not actor.actions.includes_upper_bone("L UpperArm") and actor.actions.hip_firing)
 equip("m4")
 var rifle_aim:=GameplayCommand.new();rifle_aim.aim=true
 await frames(40,rifle_aim)
 var right_hand:=pose.skeleton.find_bone("R Hand")
 var left_hand:=pose.skeleton.find_bone("L Hand")
 var right_point:=pose.skeleton.get_bone_global_pose(right_hand).origin
 var direction:Vector3=(pose.skeleton.to_local(actor.actions.aim_target)-right_point).normalized()
 var support:=right_point+direction*gun.profile.pose.support_reach-Vector3.UP*gun.profile.pose.support_drop
 var grip_error:=pose.skeleton.get_bone_global_pose(left_hand).origin.distance_to(support)
 var authored_forearm:=pose.rotation_at(actor.actions.upper_clip(),clampf(gun.profile.fire_frame_seconds-0.03,0,actor.reference_motion.duration(actor.actions.upper_clip())),forearm)
 check("two-handed aim preserves authored arm articulation",actor.actions.native_aim_hold and pose.skeleton.get_bone_pose_rotation(forearm).angle_to(authored_forearm)<0.01,grip_error)
 equip("colt45");await frames(2)
 gun.magazine=1
 var reload:=GameplayCommand.new();reload.reload=true
 await frames(1,reload);await frames(15)
 check("native VCS reload clip owns supplied arm articulation",actor.actions.reloading and actor.actions.upper_clip().to_lower()=="colt45_reload" and not actor.actions.procedural_fire,actor.actions.upper_clip())
 await frames(100)
 var jump:=GameplayCommand.new();jump.jump=true;jump.fire=true
 before_shots=gun.shots
 await frames(1,jump);jump.jump=false;await frames(15,jump)
 check("launch and airborne weapon restrictions survive animation replacement",gun.shots==before_shots,actor.phase)
 await frames(85)
 reset_actor(Vector3(-24,0.94,35));arena.rig.yaw=0;await frames(40)
 equip("shotgun");gun.cooldown=0;gun.reload_left=0
 var pump:=GameplayCommand.new();pump.fire=true;pump.aim=true
 await frames(1,pump);pump.fire=false;await frames(3,pump)
 check("pump shotgun recovery owns the native fire clip during ammunition recovery",actor.actions.native_fire_owns_upper and actor.actions.upper_clip().to_lower()=="shotgun_fire" and not actor.actions.reloading and gun.reload_left>0,actor.actions.upper_clip())
 await frames(70)
 check("pump-shot cadence waits for the source loop before the next shot",gun.cooldown<=0 and gun.magazine==1 and gun.profile.interval>=0.65,gun.profile.interval)
 equip("tec9");await frames(1)
 check("Tec9 binds the supplied TEC action block",actor.actions.resolve(PackedStringArray([gun.profile.animation_group+"_fire"]))=="TEC_fire")
 equip("unarmed");gun.cooldown=0;gun.melee.recovery=0;gun.melee.combo=0
 var punch:=GameplayCommand.new();punch.fire=true
 var start:=actor.global_position
 await frames(1,punch);await frames(42)
 var traveled:=start.distance_to(actor.global_position)
 check("unarmed attacks consume actual planar clip displacement",traveled>0.12 and traveled<0.8,{"distance_m":traveled,"clip":gun.melee.clip})
 check("source player attack stat is not multiplied into punch damage",gun.melee.strike_damage<20,gun.melee.strike_damage)
 var ped:CharacterMotor=arena.pedestrians[0]
 ped.respawn(actor.global_position+Vector3(0,0,-1.0));ped.grounded=true;ped.phase="grounded"
 var health_before:=ped.health.health
 gun.cooldown=0;gun.melee.recovery=0;gun.melee.combo=0
 await frames(1,punch);await frames(35)
 check("spatial limb sweep damages a pedestrian without instant death",ped.health.health<health_before and ped.health.health>65,{"before":health_before,"after":ped.health.health,"hits":gun.melee.hit_ids.size()})
 # Independent retaliation uses the same actor/weapon components, no player-only combat code.
 reset_actor(Vector3(-24,0.94,35));await frames(35)
 ped.respawn(actor.global_position+Vector3(0,0,-1.05));ped.grounded=true;ped.phase="grounded";ped.facing=PI;ped.visual.rotation.y=PI
 var brain:PedBrain=arena.ped_brains[0]
 brain.temper=70;brain.fear=30;brain.set_physics_process(true)
 var attack:=DamageEvent.make(1,ped.global_position,Vector3.FORWARD,"melee",actor)
 ped.receive_hit(attack)
 await frames(150)
 check("attacked pedestrians enter fight state instead of ignoring melee",brain.state=="fight" and ped.weapon.melee.combo>0,{"state":brain.state,"swings":ped.weapon.melee.combo})
 check("pedestrian melee can physically hit the player",actor.health.health<actor.health.max_health,actor.health.health)
 brain.set_physics_process(false);brain.state="wander";ped.weapon.melee.cancel();ped.respawn(Vector3(-25,0.94,24))
 reset_actor(Vector3(-24,0.94,35));await frames(35)
 equip("baseballbat");gun.cooldown=0;gun.melee.recovery=0
 await frames(1,punch)
 check("bat selects its supplied weapon swing and visible exact model",gun.melee.clip in ["WEAPON_bat_h","WEAPON_bat_v"] and actor.weapon.profile.model_scene.ends_with("baseballbat.scn"),gun.melee.clip)
 await frames(85)
 var move_attack:=GameplayCommand.new();move_attack.fire=true;move_attack.move=Vector2(0,-1)
 start=actor.global_position;gun.cooldown=0;gun.melee.recovery=0
 await frames(1,move_attack);move_attack.fire=false;await frames(35,move_attack)
 check("zero-root weapon clips permit collision-swept attack shuffling",actor.global_position.distance_to(start)>0.25,actor.global_position.distance_to(start))
 # Localized state: a bonnet hit cannot switch every panel to its damaged variant.
 car.damage.repair();car.freeze=true;car.global_position=Vector3(0,0.65,20);car.global_basis=Basis.IDENTITY
 await frames(3)
 var bonnet:String="bonnet" if car.parts.parts.has("bonnet") else car.parts.parts.keys()[0]
 var event:=DamageEvent.make(60,car.global_transform*car.parts.parts[bonnet].bounds.get_center(),Vector3.FORWARD,"melee",actor);event.part=bonnet
 var engine_before:=car.damage.health
 car.receive_hit(event)
 var damaged_count:=0
 for part in car.parts.parts.values():
  if part.state!="intact":damaged_count+=1
 check("melee damages exactly the struck panel",damaged_count==1 and car.parts.parts[bonnet].state=="damaged",damaged_count)
 check("panel damage and engine health have independent scales",car.damage.health<engine_before and engine_before-car.damage.health<event.amount,engine_before-car.damage.health)
 var destructive:=DamageEvent.make(150,event.point,Vector3.FORWARD,"melee",actor);destructive.part=bonnet
 car.receive_hit(destructive)
 await frames(2)
 check("terminal panel damage creates an independent physical fragment",car.parts.parts[bonnet].get("detached",false) and is_instance_valid(car.parts.debris.get(bonnet)) and car.parts.debris[bonnet] is RigidBody3D)
 var fragment:VehiclePartDebris=car.parts.debris[bonnet]
 fragment.queue_free();await frames(2)
 car.receive_hit(destructive);await frames(2)
 check("a missing panel cannot respawn another fragment after debris expires",not is_instance_valid(car.parts.debris.get(bonnet)) and car.parts.parts[bonnet].get("detached",false))
 car.damage.repair();await frames(2)
 check("repair restores panels and clears transient fragments",car.parts.debris.is_empty() and car.parts.parts[bonnet].state=="intact" and not car.parts.parts[bonnet].get("detached",false))
 car.freeze=false
 reset_actor(Vector3(0,0.94,15.9));actor.facing=PI;actor.visual.rotation.y=PI;arena.rig.yaw=PI
 await frames(40);gun.cooldown=0;gun.melee.recovery=0;gun.melee.combo=0
 engine_before=car.damage.health
 await frames(1,punch);await frames(80)
 check("an actual bat swing can hit car geometry",car.damage.health<engine_before,{"before":engine_before,"after":car.damage.health,"hits":gun.melee.hit_ids.size(),"tip":gun.melee.strike_tip(0.4)})
 car.damage.repair();car.reset_at(Vector3(24,0.8,5));await frames(100)
 var wall:=LabGeometry.box(arena,Vector3(6,3,0.4),Vector3(24,1.5,-3),Color.GRAY,true)
 await frames(3);car.brake=0;car.linear_velocity=Vector3(0,0,-18);await frames(70)
 damaged_count=0
 for part in car.parts.parts.values():
  if part.state!="intact":damaged_count+=1
 check("real Jolt collision damages localized panels rather than every panel",damaged_count>0 and damaged_count<car.parts.parts.size() and car.damage.health<1000,{"damaged":damaged_count,"total":car.parts.parts.size(),"health":car.damage.health})
 wall.queue_free();car.damage.repair();car.reset_at(Vector3(18,0.8,18));await frames(100)
 var radius:=car.profile.wheel_radius
 var healthy_height:=car.global_position.y
 for i in range(4):car.damage.burst_tire(i)
 await frames(120)
 var full_size:=true
 for spin in car.wheel_spinners:
  if not spin.scale.is_equal_approx(Vector3.ONE):full_size=false
 check("shot tires retain their full visual dimensions",full_size)
 check("flat tires lower physical support and let wheels sink",car.global_position.y<healthy_height-radius*0.12,{"healthy_y":healthy_height,"flat_y":car.global_position.y})
 check("flat tire grip and drag are separately configurable",car.damage.profile.flat_grip_ratio<1 and car.damage.profile.flat_drag_newtons>0)
 car.damage.repair();car.reset_at(Vector3(24,0.8,10));reset_actor(Vector3(-24,0.94,35));await frames(100)
 var throttle:=GameplayCommand.new();throttle.move=Vector2(0,-1)
 car.control_owner="external"
 var ticks:=0
 while ticks<180 and car.speed<10:
  car.command(throttle);await frames(1);ticks+=1
 metrics.acceleration={"seconds_to_10mps":ticks/60.0,"speed":car.speed}
 check("native car acceleration reaches 10 m/s within two seconds",car.speed>=10 and ticks<=120,metrics.acceleration)
 car.park();car.reset_at(Vector3(0,0.8,40));await frames(100)
 car.linear_velocity=Vector3(0,0,-22)
 var turn:=GameplayCommand.new();turn.move=Vector2(1,-1)
 var minimum_up:=1.0
 var maximum_steer:=0.0
 for i in range(150):
  car.command(turn);await frames(1)
  minimum_up=minf(minimum_up,car.global_basis.y.y)
  maximum_steer=maxf(maximum_steer,absf(car.steering))
 metrics.cornering={"minimum_up_dot":minimum_up,"maximum_steer":maximum_steer,"speed":car.speed}
 check("high-speed turning uses curvature-limited steering without routine flips",minimum_up>0.65,metrics.cornering)
 car.park();car.damage.repair();car.reset_at(Vector3(10,1.3,12));await frames(50)
 for roll in [PI*0.5,PI]:
  car.freeze=true;car.global_transform=Transform3D(Basis(Vector3.FORWARD,roll),Vector3(10,1.3,12))
  actor.respawn(Vector3(-24,0.94,35));board(car);await frames(3)
  var began:=transition.request_exit()
  check("tilted vehicle exit finds a clear upright destination "+str(roll),began,transition.message)
  if began:
   check("overturned exit selects supplied crawl animation "+str(roll),transition.escape_clip=="CAR_crawloutRHS",transition.escape_clip)
   check("crawl pose mirrors to the selected door "+str(roll),(actor.reference_pose.scale.x<0)==(transition.exit_side%2==0))
   await frames(ceili(transition.exit_total*60)+8)
   check("tilted exit releases occupancy and restores on-foot control "+str(roll),transition.state=="on_foot" and actor.control_enabled and car.driver==null,{"state":transition.state,"at":actor.global_position})
  if transition.vehicle!=null:transition.recover()
 car.freeze=false;car.reset_at(Vector3(18,0.8,28));await frames(100)
 actor.respawn(Vector3(-24,0.94,35));board(car);await frames(2)
 car.linear_velocity=Vector3(0,0,-12)
 var moving_exit:=transition.request_exit()
 check("moving car permits a validated bailout",moving_exit and transition.state=="ejecting",transition.state)
 await frames(15)
 check("bailout transfers control once and frees vehicle occupancy",transition.state=="on_foot" and car.driver==null and car.seating.reservations.is_empty() and actor.reaction_body.active)
 check("bailout preserves vehicle momentum in a physical reaction body",actor.reaction_body.linear_velocity.length()>4,{"velocity":actor.reaction_body.linear_velocity,"clip":actor.actions.life_clip})
 check("moving car uses supplied rollout animation",actor.actions.life_clip in ["CAR_rollout_LHS","CAR_rollout_RHS"],actor.actions.life_clip)
 car.park();await frames(200)
 car.reset_at(Vector3(-28,0.8,38));await frames(90)
 # The bike collection is data driven and owns two independent contact solvers.
 var bikes:Array[DriveVehicle]=[]
 for child in arena.get_children():
  if child is DriveVehicle and child.kind=="bike":bikes.append(child)
 check("four actual bike types are installed",bikes.size()==4,bikes.size())
 check("car and bike contact lists remain independent per instance",car.wheel_indices().size()==4 and bikes.all(func(b:DriveVehicle):return b.wheel_indices().size()==2))
 check("bikes have no invisible car windshield hit region",bikes.all(func(b:DriveVehicle):return b.damage.glass_region==null))
 check("bike handlebars and forks have independent steering presentation bindings",bikes.all(func(b:DriveVehicle):return b.bike.steering_nodes.size()==2))
 for bike in bikes:
  bike.damage.repair();bike.reset_at(Vector3(18,0.7,0));bike.bike.mounting=true;await frames(120)
  var supported:=bike.wheels[0].touching and bike.wheels[2].touching
  check("two-contact bike mount assistance settles upright "+String(bike.name),supported and bike.global_basis.y.y>0.9,{"at":bike.global_position,"up":bike.global_basis.y.y})
  actor.respawn(bike.approach_position(0,1 if bike.name=="sanchez" else 0));actor.facing=0;await frames(30)
  var entered:=transition.request_enter(bike)
  check("bike entry uses LCS mount clip "+String(bike.name),entered and transition.clip_for("getin",transition.entry_side).begins_with(bike.bike_animation),transition.clip_for("getin",transition.entry_side))
  if not entered:continue
  await TransitionTestWait.approach(arena)
  await frames(ceili(transition.enter_total*60)+10)
  check("bike seat commits unique driver "+String(bike.name),bike.driver==actor and transition.state=="driving")
  if bike.name=="sanchez":check("right-side bike mount reserves the driver and uses right mount clip",transition.entry_side==1 and transition.seat_index==0)
  await frames(90,throttle)
  check("bike accelerates with a balanced visible rider "+String(bike.name),absf(bike.speed)>3 and bike.global_basis.y.y>0.65,{"speed":bike.speed,"up":bike.global_basis.y.y,"clip":actor.reference_motion.clip})
  bike.linear_velocity=Vector3.ZERO;bike.angular_velocity=Vector3.ZERO
  # Hold the chassis while checking the independent stationary get-off transaction.
  bike.freeze=true;await frames(2)
  var left:=transition.request_exit()
  check("bike exit uses LCS dismount clip "+String(bike.name),left and transition.escape_clip.begins_with(bike.bike_animation),transition.escape_clip)
  if left:await frames(ceili(transition.exit_total*60)+10)
  check("bike dismount restores continuous on-foot loop "+String(bike.name),transition.state=="on_foot" and actor.control_enabled and bike.driver==null)
  if transition.vehicle!=null:transition.recover()
  bike.freeze=false;bike.reset_at(Vector3(8+bikes.find(bike)*3,0.7,-36));await frames(5)
 var fast_bike:DriveVehicle=bikes[0]
 fast_bike.reset_at(Vector3(18,0.7,10));await frames(100);board(fast_bike);await frames(2)
 fast_bike.linear_velocity=Vector3(0,0,-12)
 var bike_bail:=transition.request_exit()
 check("moving bike accepts a validated jump-off",bike_bail and transition.state=="ejecting")
 await frames(15)
 check("bike jump-off uses the model rear get-off clip and releases its seat",transition.state=="on_foot" and fast_bike.driver==null and actor.reaction_body.active and actor.actions.life_clip==fast_bike.bike_animation+"_getoffBACK",actor.actions.life_clip)
 fast_bike.park();fast_bike.reset_at(Vector3(18,0.7,10));await frames(100)
 var other_driver:=Node3D.new();arena.add_child(other_driver)
 fast_bike.seating.reserve(other_driver,0);fast_bike.seating.commit(other_driver,0)
 fast_bike.control_owner="external"
 board(fast_bike,1);await frames(2)
 fast_bike.control_owner="external";fast_bike.linear_velocity=Vector3(0,0,-8)
 var passenger_bail:=transition.request_exit();await frames(15)
 check("passenger bailout cannot steal an existing driver's control",passenger_bail and transition.state=="on_foot" and fast_bike.driver==other_driver and fast_bike.control_owner=="external")
 fast_bike.release_seat(other_driver);other_driver.queue_free()
 metrics.orchestration=arena.telemetry.summary()
 var report:={"engine":Engine.get_version_info().string,"backend":"Jolt Physics","assertions":results.size(),"failures":failures,"results":results,"metrics":metrics,"reference_runtime_parity":false}
 FileAccess.open("res://tests/stories_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("RESULT stories ",results.size()," / failures ",failures)
 arena.queue_free();await process_frame;quit(1 if failures else 0)
