extends SceneTree
var arena:Node3D
var results:Array[Dictionary]=[]
var failures:=0
func _initialize()->void:run.call_deferred()
func check(label:String,ok:bool,value:Variant=null)->void:
 results.append({"name":label,"passed":ok,"measured":value})
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label," ",value)
func frames(n:int,cmd:GameplayCommand=null)->void:
 arena.injected_command=cmd if cmd!=null else GameplayCommand.new()
 for i in range(n):await physics_frame;await process_frame
func reset(at:Vector3)->void:
 arena.transition.abort_for_respawn();arena.actor.facing=0;arena.actor.respawn(at);arena.rig.yaw=0
func ground(at:Vector3)->Dictionary:
 return arena.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*15,at-Vector3.UP*20,1))
func carry_math(state:ActorActionState)->void:
 var skeleton:=Skeleton3D.new();root.add_child(skeleton)
 var names:=["Root","Spine","Spine1","Neck","R Hand","L Hand"]
 for name in names:skeleton.add_bone(name)
 for i in range(1,6):skeleton.set_bone_parent(i,2 if i>2 else i-1)
 skeleton.set_bone_pose_position(2,Vector3.UP)
 skeleton.set_bone_pose_position(3,Vector3.UP*0.4)
 skeleton.set_bone_pose_position(4,Vector3(0.4,0.1,-0.5))
 skeleton.set_bone_pose_position(5,Vector3(-0.2,0.1,-0.6))
 skeleton.force_update_all_bone_transforms()
 var grip:=skeleton.get_bone_global_pose(4).affine_inverse()*skeleton.get_bone_global_pose(5)
 var head:=skeleton.get_bone_global_pose(3).basis.get_rotation_quaternion()
 var helper:=SkinnedMotionVisual.new();helper.skeleton=skeleton;helper.actions=state
 state.standing_hold_weight=1;state.aim_weight=0
 helper.lower_native_carry()
 var after:=skeleton.get_bone_global_pose(4).affine_inverse()*skeleton.get_bone_global_pose(5)
 check("lowered carry preserves both hands as a rigid authored grip",grip.origin.distance_to(after.origin)<0.00001 and grip.basis.get_rotation_quaternion().angle_to(after.basis.get_rotation_quaternion())<0.001)
 check("lowered carry preserves head direction and root pose",head.angle_to(skeleton.get_bone_global_pose(3).basis.get_rotation_quaternion())<0.001 and skeleton.get_bone_pose_rotation(0)==Quaternion.IDENTITY)
 var held:=skeleton.get_bone_pose_rotation(2);state.aim_weight=1;helper.lower_native_carry()
 check("aiming cancels the relaxed carry lowering",held.angle_to(skeleton.get_bone_pose_rotation(2))<0.001)
 helper.free();skeleton.queue_free();state.aim_weight=0
func run()->void:
 arena=load("res://scenes/arena.tscn").instantiate();arena.test_mode=true;arena.enable_reference_assets=false;root.add_child(arena);await frames(60)
 var actor:CharacterMotor=arena.actor
 actor.configure_reference(ImportedGameplayDatabase.new(),"STAT_PLAYER",TraversalTestFixture.library())
 var course:TraversalCourse=arena.traversal_course
 check("map has graded slopes, platform garden, drop decks and void loop",course.slopes.size()==6 and course.garden.size()==7 and course.drop_decks.size()==4 and course.void_platforms.size()==13)
 for ramp in course.slopes:
  var hit:=ground(ramp.global_position)
  var angle:float=ramp.get_meta("angle_degrees")
  check("ramp %d collision matches its angle"%int(angle),not hit.is_empty() and absf(rad_to_deg(acos(clampf(hit.normal.y,-1,1)))-angle)<0.1)
 for deck in course.drop_decks:
  var hit:=ground(Vector3(deck.global_position.x,0,deck.global_position.z))
  check("drop deck has advertised top height",not hit.is_empty() and absf(hit.position.y-deck.global_position.y-0.15)<0.02)
 check("void loop has a real gap with no hidden catch floor",ground(Vector3(12,0,90)).is_empty())
 for index in [0,2,4]:
  var front:Vector3=course.profile.slope_start+Vector3.RIGHT*index*course.profile.slope_spacing
  var angle:float=course.profile.slope_angles[index]
  reset(front+Vector3(0,0.94,1.5));await frames(20)
  var climb:=GameplayCommand.new();climb.move=Vector2(0,-1);climb.walk=true
  var high:=0.0;var reached:=false
  for frame in range(480):
   await frames(1,climb)
   high=maxf(high,actor.global_position.y-0.9)
   if actor.grounded and actor.global_position.z<front.z-course.profile.slope_run-0.1:reached=true;break
  check("ramp %d respects the climb limit"%int(angle),(reached and high>0.5) if angle<45 else (not reached and high<0.5),{"height":high,"reached":reached})
 for sprinting in [false,true]:
  reset(Vector3(-28,0.94,38));await frames(20)
  var cmd:=GameplayCommand.new();cmd.move=Vector2(0,-1);cmd.sprint=sprinting
  await frames(50,cmd);cmd.jump=true;await frames(1,cmd);cmd.jump=false
  var contact_frames:=0;var stride_frames:=0;var had_air:=false;var had_land:=false
  for frame in range(180):
   await frames(1,cmd);had_air=had_air or not actor.grounded
   if actor.landing.active:
    had_land=true
    var layers:=actor.landing.pose_layers()
    if layers[0].weight>0.5:contact_frames+=1
    if layers.size()>1 and layers[1].weight>0.5:stride_frames+=1
   if had_land and not actor.landing.active:break
  check(("sprint" if sprinting else "run")+" jump passes through contact and stride after collision",had_air and contact_frames>=6 and stride_frames>=8,{"contact_frames":contact_frames,"stride_frames":stride_frames})
  await frames(25,cmd)
  check("landing returns to normal grounded locomotion",actor.phase=="grounded" and actor.drive_velocity.length()>2 and actor.can_use_weapon())
 var gun:WeaponController=actor.weapon
 var profiles:Array[WeaponProfile]=[]
 for group in ["RIFLE","shotgun"]:
  var p:=WeaponProfile.new();p.animation_group=group;p.two_handed=true;p.fire_frame_seconds=0.25;p.pose=load("res://tuning/standing_long_gun_pose.tres");profiles.append(p)
 gun.configure_loadout(profiles)
 for slot in range(2):
  gun.equip_slot(slot)
  for phase in ["idle","start","move","stop"]:
   actor.reference_motion.phase=phase
   var cmd:=GameplayCommand.new();cmd.move=Vector2(0,-1) if phase!="idle" else Vector2.ZERO
   for i in range(20):actor.actions.tick(cmd,gun,1.0/60)
   check(gun.profile.animation_group+" keeps the supported grip in "+phase,actor.actions.standing_hold_weight>0.999 and actor.actions.standing_hold_native_ready and actor.actions.standing_hold_clip==gun.profile.animation_group+"_fire" and actor.actions.aim_weight==0)
  var sprint:=GameplayCommand.new();sprint.move=Vector2(0,-1);sprint.sprint=true
  for i in range(20):actor.actions.tick(sprint,gun,1.0/60)
  check("sprint yields to its full-body action",actor.actions.standing_hold_weight==0 and not actor.actions.upper_allowed)
  actor.reference_motion.phase="seated"
  for i in range(20):actor.actions.tick(GameplayCommand.new(),gun,1.0/60)
  check("bike seat pose cannot inherit long-gun holding",actor.actions.standing_hold_weight==0 and not actor.actions.upper_allowed)
 carry_math(actor.actions)
 # A native moving landing must expose contact compression before its stride.
 var land:=ActorLandingState.new()
 check("confirmed jumps can land on higher surfaces despite a short descent",land.start(actor.actions,0.4,0.05,1.5,5,false,true))
 var contact:=0.0;var stride:=0.0;var elapsed:=0.0
 while land.active:
  var previous:=land.time;land.tick(1.0/60);elapsed+=1.0/60
  var layers:=land.pose_layers()
  if layers[0].weight>0.5:contact+=1.0/60
  if layers.size()>1 and layers[1].weight>0.5:stride+=1.0/60
  if land.time<=previous:break
 check("contact and running follow-through are both visible",contact>=0.10 and stride>=0.16 and elapsed<0.8,{"contact":contact,"stride":stride,"total":elapsed})
 var travel:Array[Vector3]=[]
 for hz in [30,60,120]:
  land=ActorLandingState.new();land.start(actor.actions,0.7,1,6,5,false,true)
  var delta:=Vector3.ZERO
  while land.active:land.tick(1.0/hz);delta+=land.travel
  travel.append(delta)
 check("spatial landing travel is stable at 30/60/120 Hz",travel[0].distance_to(travel[2])<0.02 and travel[1].distance_to(travel[2])<0.01,travel)
 land=ActorLandingState.new();land.start(actor.actions,0.8,4,12,4,true)
 check("roll requires a grounded hard moving impact",land.kind=="roll" and land.clip=="FALL_fall")
 reset(Vector3(12,8,90));var recoveries:int=arena.player_spawn.recoveries
 var fall_frames:=0;var invalid:=false
 for i in range(240):
  await frames(1)
  if actor.fall.falling:
   fall_frames+=1;invalid=invalid or actor.reference_motion.clip!="FALL_glide" or actor.reaction_body.active or actor.actions.life!="alive"
  if arena.player_spawn.recoveries>recoveries:break
 check("void descent never turns into an airborne roll",fall_frames>30 and not invalid,fall_frames)
 check("void recovery reuses the original actor at its safe spawn",arena.player_spawn.recoveries==recoveries+1 and actor.health.health==100 and actor.global_position.distance_to(arena.player_spawn.spawn_position)<0.1)
 # A motorcycle entering the standing volume interrupts get-up safely.
 reset(Vector3(-40,0.94,40));await frames(30)
 var car:DriveVehicle=arena.vehicle;car.kind="bike";car.freeze=true
 car.global_position=actor.global_position+Vector3.UP*0.3
 await physics_frame;await process_frame
 actor.actions.life="getting_up";actor.actions.life_time=0;actor.actions.life_clip="GETUP";actor.control_enabled=false
 await frames(1)
 check("bike overlap interrupts get-up into solid physical recovery",actor.actions.life=="down" and actor.reaction_body.active and not actor.control_enabled and actor.reaction_body.collision_mask!=0)
 car.global_position=Vector3(30,2,-40)
 await frames(360)
 check("clearing the bike permits a normal get-up without control lock",actor.actions.life=="alive" and actor.control_enabled)
 var report:={"engine":Engine.get_version_info().string,"assertions":results.size(),"failures":failures,"results":results,"assets":"synthetic clips and primitive collision","native_visual_validation":false,"android_device_tested":false}
 var f:=FileAccess.open("res://tests/traversal_contract_results.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("RESULT traversal contracts ",results.size()," / failures ",failures)
 arena.queue_free();await process_frame;quit(1 if failures else 0)
