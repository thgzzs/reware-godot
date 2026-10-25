extends SceneTree
var arena:Node3D
var results:Array[Dictionary]=[]
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(label:String,ok:bool,value:Variant=null) -> void:
 results.append({"name":label,"passed":ok,"measured":value});if not ok:failures+=1
 print("PASS "if ok else"FAIL ",label," ",value)
func frames(n:int,cmd:GameplayCommand=null) -> void:
 arena.injected_command=cmd if cmd!=null else GameplayCommand.new()
 for i in range(n):await physics_frame;await process_frame
func reset(at:=Vector3(-28,0.94,38)) -> void:
 arena.actor.respawn(at);arena.actor.facing=0;arena.actor.visual.rotation.y=0;arena.rig.yaw=0;arena.rig.pitch=0
func run() -> void:
 arena=load("res://scenes/arena.tscn").instantiate();arena.test_mode=true;root.add_child(arena);await frames(100)
 for brain in arena.ped_brains:brain.set_physics_process(false)
 var actor:CharacterMotor=arena.actor
 var pose:SkinnedMotionVisual=actor.reference_pose
 var cmd:=GameplayCommand.new();cmd.move=Vector2(0,-1)
 for walk in [true,false]:
  reset();await frames(40);cmd.walk=walk;await frames(100,cmd)
  var maximum_error:=0.0
  var maximum_lateral:=0.0
  var travel:=0.0
  for i in range(80):
   var motion:=actor.reference_motion
   var name:String=motion.walk_clip if walk else motion.run_clip
   var a:=motion.library.get_animation(name)
   var track:int=motion.roots[name]
   var previous:=motion.cycle*a.length
   var before:=actor.global_position
   await frames(1,cmd)
   var next:=motion.cycle*a.length
   var local_delta:=a.position_track_interpolate(track,next)-a.position_track_interpolate(track,previous)
   if next<previous:local_delta=a.position_track_interpolate(track,a.length)-a.position_track_interpolate(track,previous)+a.position_track_interpolate(track,next)-a.position_track_interpolate(track,0)
   local_delta.y=0
   var actual:=actor.global_position-before;actual.y=0
   var expected:=Basis(Vector3.UP,actor.facing)*local_delta
   maximum_error=maxf(maximum_error,actual.distance_to(expected));travel+=actual.length()
   maximum_lateral=maxf(maximum_lateral,absf(actual.dot(Basis(Vector3.UP,actor.facing)*Vector3.RIGHT)))
  check(("walk"if walk else"run")+" collision travel follows the actual animation root every tick",maximum_error<0.003 and travel>1,{"error_m":maximum_error,"distance_m":travel,"lateral_m":maximum_lateral})
 reset();await frames(40);cmd.walk=false;await frames(100,cmd)
 var turn:=GameplayCommand.new();turn.move=Vector2(1,0)
 var max_rate:=0.0;var slide:=0.0
 for i in range(45):
  var heading:=actor.facing;var before:=actor.global_position
  await frames(1,turn)
  max_rate=maxf(max_rate,absf(angle_difference(heading,actor.facing))*60)
  var delta:=actor.global_position-before;delta.y=0
  slide=maxf(slide,absf(delta.dot(Basis(Vector3.UP,actor.facing)*Vector3.RIGHT)))
 check("running cornering has a bounded tank-like heading rate",max_rate<=actor.profile.standing_turn_rate+0.01 and max_rate<6,max_rate)
 check("direction changes do not retain a sideways inertial velocity",slide<0.015,slide)
 var reverse:=GameplayCommand.new();reverse.move=Vector2(-1,0)
 var was:=actor.facing;await frames(1,reverse)
 check("opposite input cannot instantly reverse the facing",absf(angle_difference(was,actor.facing))<0.07)
 var speed_before:=actor.drive_velocity.length();await frames(25,reverse)
 check("reversal brakes before accelerating in the new direction",actor.steering.reversing or actor.drive_velocity.length()<speed_before,{"before":speed_before,"after":actor.drive_velocity.length()})
 reset();await frames(40);await frames(80,cmd)
 var jump:=GameplayCommand.new();jump.move=cmd.move;jump.jump=true
 var heading:=actor.facing;var launch_start:=actor.global_position
 await frames(1,jump)
 jump.jump=false
 var launch_travel:=0.0;var air_turn:=0.0;var saw_air:=false;var saw_land:=false;var land_travel:=0.0;var land_clock:=true;var landing_heading:=0.0;var landing_turn:=0.0
 for i in range(170):
  var before:=actor.global_position;var previous_time:=actor.landing.time
  var input:=GameplayCommand.new();input.move=Vector2(sin(i*0.4),cos(i*0.4));arena.rig.yaw=i*0.2
  await frames(1,input)
  var delta:=actor.global_position-before;delta.y=0
  if actor.phase=="launch":launch_travel+=delta.length()
  if actor.phase in ["airborne","falling"]:
   saw_air=true;air_turn=maxf(air_turn,absf(angle_difference(heading,actor.facing)))
  if actor.landing.active:
   if not saw_land:landing_heading=actor.facing
   saw_land=true;land_travel+=delta.length();landing_turn=maxf(landing_turn,absf(angle_difference(landing_heading,actor.facing)))
   if previous_time>0:land_clock=land_clock and actor.landing.time>previous_time
  if saw_land and not actor.landing.active:break
 check("jump launch consumes spatial animation travel",launch_travel>0.02,launch_travel)
 check("camera and movement input cannot spin an airborne player",saw_air and air_turn<0.0001,air_turn)
 check("landing is a progressing spatial clip rather than an idle slide",saw_land and land_travel>0.1 and land_clock,{"distance_m":land_travel,"clip":actor.landing.clip})
 check("landing contact retains its heading",landing_turn<0.0001,landing_turn)
 var bikes:Array[DriveVehicle]=[]
 for child in arena.get_children():
  if child is DriveVehicle and child.kind=="bike":bikes.append(child)
 var parked:=true
 for bike in bikes:parked=parked and bike.bike.standing and bike.global_basis.y.dot(Vector3.UP)>0.98
 check("empty parked bikes stand upright instead of hovering at an arbitrary lean",bikes.size()==4 and parked,bikes.map(func(b:DriveVehicle):return b.global_basis.y.y))
 var bike:=bikes[0]
 bike.reset_at(Vector3(-10,0.8,38));bike.reset_transform.basis=Basis(Vector3.FORWARD,1.2);bike.bike.standing=false;await frames(200)
 check("a genuinely fallen bike settles fully on its side",absf(bike.global_basis.y.dot(Vector3.UP))<0.25 and bike.linear_velocity.length()<0.3,{"up":bike.global_basis.y.y,"speed":bike.linear_velocity.length()})
 check("fallen wheel rays no longer prop up the chassis",not bike.wheels[0].touching and not bike.wheels[2].touching)
 reset(bike.approach_position(0,0));await frames(40)
 var entered:bool=arena.transition.request_enter(bike)
 if entered:
  for i in range(650):
   await frames(1)
   if i%30==0 and arena.transition.state=="lifting":print("LIFT ",arena.transition.lift_elapsed," up ",bike.global_basis.y," angular ",bike.angular_velocity," pos ",bike.global_position," progress ",bike.bike.lift_progress)
   if arena.transition.state in ["driving","on_foot"]:break
 check("side-resting bike still supports physical pickup and mounting",entered and arena.transition.state=="driving",arena.transition.message)
 if arena.transition.state!="driving":
  arena.transition.recover();bike.reset_at(Vector3(-10,0.7,38));bike.bike.standing=true;await frames(90)
  reset(bike.approach_position(0));bike.reserve_seat(actor,0);bike.commit_seat(actor,0);actor.set_embarked(true);arena.transition.vehicle=bike;arena.transition.seat_index=0;arena.transition.state="driving"
 var drive:=GameplayCommand.new();drive.move=Vector2(0,-1);await frames(45,drive)
 var seated_pose:=pose.skeleton.get_bone_pose_rotation(pose.skeleton.find_bone("R Thigh"))
 var wall:=LabGeometry.box(arena,Vector3(6,3,0.4),bike.global_position+Vector3(0,0,-4)+Vector3.UP,Color.GRAY,true);await frames(2)
 bike.linear_velocity=Vector3(0,0,-14);bike.brake=0
 var ejected:=false;var cleared:=false;var changed_pose:=false
 for i in range(90):
  await frames(1)
  if arena.transition.state=="on_foot" and actor.reaction_body.active:
   ejected=true
   cleared=actor.reference_motion.vehicle_layers.is_empty() and actor.reference_motion.pose_layers().all(func(l:Dictionary):return "_Ride"not in l.clip and "_Still"not in l.clip and "_Left"not in l.clip and "_Right"not in l.clip)
   changed_pose=changed_pose or pose.skeleton.get_bone_pose_rotation(pose.skeleton.find_bone("R Thigh")).angle_to(seated_pose)>0.2
 check("crash hands pose ownership away from every riding layer",ejected and cleared)
 check("ejected rider limbs change from the seated pose",changed_pose)
 wall.queue_free();arena.transition.recover();reset(Vector3(-28,80,38));actor.actions.begin_life("down");actor.control_enabled=false
 actor.reaction_body.launch_velocity(actor.global_position,0,Vector3(2,0,-3));actor.actions.life_clip=actor.actions.resolve(PackedStringArray(["BIKE_fall_off","FALL_glide"]))
 var tilt:=0.0;var yaw:=0.0;var angular:=0.0
 for i in range(90):
  await frames(1)
  tilt=maxf(tilt,actor.visual.global_basis.get_rotation_quaternion().angle_to(Quaternion.IDENTITY));yaw=maxf(yaw,absf(actor.visual.global_basis.get_euler().y));angular=maxf(angular,actor.reaction_body.angular_velocity.length())
 check("physical falls retain bounded presentation instead of wheel spins",tilt<1.25 and yaw<0.01,{"tilt_rad":tilt,"yaw_rad":yaw})
 check("physical fall angular speed is bounded",angular<=actor.reaction_body.profile.maximum_angular_speed+0.05,angular)
 var report:={"engine":Engine.get_version_info().string,"backend":"Jolt Physics","assertions":results.size(),"failures":failures,"results":results,"reference_runtime_parity":false}
 var f:=FileAccess.open("res://tests/spatial_motion_results.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("RESULT spatial motion ",results.size()," / failures ",failures)
 arena.queue_free();await process_frame;quit(1 if failures else 0)
