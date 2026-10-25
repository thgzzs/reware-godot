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
func reset(at:=Vector3(-48,0.94,38)) -> void:
 arena.transition.abort_for_respawn();arena.actor.respawn(at);arena.actor.facing=0;arena.actor.visual.rotation.y=0;arena.rig.yaw=0
func paint(mesh:MeshInstance3D) -> Color:
 var material:BaseMaterial3D=mesh.material_override if mesh.material_override!=null else mesh.get_active_material(0)
 return material.albedo_color
func run() -> void:
 arena=load("res://scenes/arena.tscn").instantiate();arena.test_mode=true;root.add_child(arena);await frames(100)
 for brain in arena.ped_brains:brain.set_physics_process(false)
 var actor:CharacterMotor=arena.actor
 var car:DriveVehicle=arena.vehicle
 var bike:DriveVehicle=arena.get_node("pcj600")
 check("player steering increases again while retaining a bounded response",actor.profile.player_turn_multiplier>=1.6 and actor.profile.running_turn_rate<4.0 and actor.profile.standing_turn_rate<6.0,actor.profile.running_turn_rate)
 for direction in [Vector3.BACK,Vector3.FORWARD,Vector3.LEFT,Vector3.RIGHT]:
  reset();await frames(40)
  actor.receive_hit(DamageEvent.make(12,actor.global_position,direction,"bullet"))
  var start:=actor.global_position;var heading:=actor.facing
  var clip:=actor.actions.reaction_clip
  var anim:=actor.reference_motion.library.get_animation(clip)
  var track:int=actor.reference_motion.roots[clip]
  var expected:=Vector3.ZERO;var error:=0.0;var turned:=0.0;var travel:=0.0
  var move:=GameplayCommand.new();move.move=Vector2(1,0);move.aim=true;move.fire=true;move.jump=true
  for i in range(80):
   var before:=actor.global_position
   var previous:=actor.actions.reaction_time/maxf(0.001,actor.actions.reaction_duration)*anim.length
   await frames(1,move)
   if not actor.actions.spatial_hit():break
   var at:=actor.actions.reaction_at()
   expected=anim.position_track_interpolate(track,at)-anim.position_track_interpolate(track,previous);expected.y=0
   var actual:=actor.global_position-before;actual.y=0
   error=maxf(error,actual.distance_to(Basis(Vector3.UP,heading)*expected));travel+=actual.length()
   turned=maxf(turned,absf(angle_difference(heading,actor.facing)))
  check(clip+" uses exact native spatial travel despite movement/aim input",error<0.003 and travel>0.01,{"maximum_error":error,"travel_m":travel})
  check(clip+" blocks jump and heading overrides during stagger",turned<0.0001 and actor.jump_count==0,turned)
 reset();await frames(30)
 var wall:=LabGeometry.box(arena,Vector3(4,3,0.3),actor.global_position+Vector3(0,0.7,1),Color.GRAY,true);await frames(2)
 var stagger_start:=actor.global_position
 actor.receive_hit(DamageEvent.make(12,actor.global_position,Vector3.BACK,"bullet"));await frames(45)
 check("spatial hit travel stops at collision instead of passing through a wall",actor.global_position.z-stagger_start.z<0.56 and actor.global_position.z-stagger_start.z>0.1,actor.global_position-stagger_start)
 wall.queue_free();await frames(2)
 # Low-speed steering: measure the physical front wheel command, not only a tuning value.
 reset();await frames(30)
 for vehicle in [car,bike]:
  vehicle.damage.repair();vehicle.reset_at(Vector3(-45 if vehicle.kind=="car" else -25,0.9,10));await frames(90)
  var command:=GameplayCommand.new();command.move=Vector2(1,0)
  vehicle.command(command,"external");await frames(45)
  check(vehicle.kind+" steering has 25 percent more low-speed range",absf(vehicle.steering)>vehicle.profile.steering_angle*1.15 and absf(vehicle.steering)<=vehicle.profile.steering_angle*1.26,{"actual":vehicle.steering,"old_lock":vehicle.profile.steering_angle})
  vehicle.park()
 # Approach from outside the side marker with a deliberately opposed heading.
 for vehicle in [car,bike]:
  vehicle.damage.repair();vehicle.reset_at(Vector3(-40 if vehicle.kind=="car" else -25,0.85,20));await frames(90)
  for side in [0,1]:
   var point:Vector3=vehicle.approach_position(side if vehicle.kind=="car" else 0,side if vehicle.kind=="bike" else -1)
   reset(point+Vector3(-0.65 if side==0 else 0.65,0,0));actor.facing=PI;actor.visual.rotation.y=PI;await frames(25)
   var began:bool=arena.transition.request_enter(vehicle)
   var elapsed:=0.0;var passed_align:=false
   if began:
    for i in range(180):
     await frames(1);elapsed+=1.0/60.0;passed_align=passed_align or arena.transition.approach.aligning
     if arena.transition.state!="approaching":break
   check(vehicle.kind+" side "+str(side)+" reaches the entry marker promptly",began and arena.transition.state=="entering" and elapsed<1.8 and passed_align,{"seconds":elapsed,"state":arena.transition.state,"message":arena.transition.message})
   arena.transition.abort_for_respawn()
 reset(bike.approach_position(0,0));await frames(25)
 var alignment_started:bool=arena.transition.request_enter(bike)
 if alignment_started:await frames(1)
 var held_alignment:bool=arena.transition.approach.aligning and not actor.control_enabled
 arena.transition.cancel_approach("test cancellation")
 check("cancelled close alignment immediately releases control and the seat",alignment_started and held_alignment and actor.control_enabled and bike.seating.reservations.is_empty())
 # Alias evidence: reVC maps semantic LHS to literal R-suffixed pickup/pullup clips.
 for side in [0,1]:
  for roll in [-1.2,1.2]:
   reset();bike.damage.repair();bike.reset_at(Vector3(-28,0.85,38));bike.reset_transform.basis=Basis(Vector3.FORWARD,roll);bike.bike.standing=false;await frames(160)
   var pick:bool=bike.global_basis.x.dot(Vector3.UP)*(1 if side==0 else -1)>0
   arena.transition.vehicle=bike;arena.transition.entry_side=side;arena.transition.seat_index=0
   bike.reserve_seat(actor,0);actor.global_position=bike.approach_position(0,side);arena.transition.begin_lift()
   var expected:=("BIKE_pickup"if pick else"BIKE_pullup")+("R"if side==0 else"L")
   check("pickup side/tilt "+str(side)+"/"+str(roll)+" resolves the source action alias",arena.transition.lift_clip==expected,arena.transition.lift_clip)
   var pose:SkinnedMotionVisual=actor.reference_pose
   actor.reference_motion.preview_clip=arena.transition.lift_clip
   actor.reference_motion.preview_time=actor.reference_motion.duration(arena.transition.lift_clip)*0.5
   pose.sample_pose(1)
   var grip:Vector3=(pose.skeleton.get_bone_global_pose(pose.skeleton.find_bone("L Hand")).origin+pose.skeleton.get_bone_global_pose(pose.skeleton.find_bone("R Hand")).origin)*0.5
   check("pickup hands reach toward the bike from side "+str(side)+"/"+str(roll),grip.x*(1 if side==0 else -1)>0.3,grip)
   actor.reference_motion.preview_clip=""
   arena.transition.abort_for_respawn()
 # Wreck lifecycle with a duplicate fast test clock; shipped delay remains 20 seconds.
 reset(Vector3(-48,0.94,50));car.damage.repair();car.reset_at(Vector3(-48,0.9,10));await frames(90)
 car.recovery.profile=car.recovery.profile.duplicate();car.recovery.profile.destroyed_seconds=1.0
 car.damage.profile=car.damage.profile.duplicate();car.damage.profile.blast_damage=0;car.damage.profile.blast_impulse=0
 var body:MeshInstance3D=car.get_node("Body")
 var color:=paint(body);var original:=body.material_override
 var other_body:MeshInstance3D=arena.get_node("pcj600/Body")
 var other_color:=paint(other_body)
 car.damage.detonate();await frames(20)
 check("exploded vehicle is visibly scorched using private materials",paint(body).get_luminance()<color.get_luminance()*0.25 and body.material_override!=original,paint(body))
 check("scorch does not mutate another vehicle",paint(other_body).is_equal_approx(other_color))
 check("wreck is retained before the configured respawn delay",car.damage.state=="destroyed" and car.recovery.respawns==0)
 await frames(65)
 check("wreck returns repaired to its spawn after the delay",car.damage.state=="healthy" and car.recovery.respawns==1 and car.global_position.distance_to(car.spawn_position)<1.0,{"state":car.damage.state,"at":car.global_position})
 check("recycling restores paint, tires, glass and vehicle ownership",body.material_override==original and paint(body).is_equal_approx(color) and not car.damage.wheel_flat.has(true) and car.damage.glass_state=="intact" and car.driver==null)
 var block:=LabGeometry.box(arena,Vector3(24,2,24),car.spawn_position+Vector3.UP,Color.GRAY,true);await frames(3)
 car.reset_at(Vector3(-48,0.9,10));await frames(60);car.damage.detonate();await frames(100)
 check("blocked parking area defers wreck respawn without overlap",car.damage.state=="destroyed" and car.recovery.respawns==1)
 block.queue_free();await frames(80)
 check("clearing the parking area resumes the same pending respawn",car.damage.state=="healthy" and car.recovery.respawns==2)
 var report:={"engine":Engine.get_version_info().string,"assertions":results.size(),"failures":failures,"results":results,"reference_runtime_parity":false,"android_device_tested":false}
 var f:=FileAccess.open("res://tests/actions_revision_results.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("RESULT actions revision ",results.size()," / failures ",failures)
 arena.queue_free();await process_frame;quit(1 if failures else 0)
