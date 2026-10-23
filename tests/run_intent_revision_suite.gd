extends SceneTree
var arena:Node3D
var results:Array[Dictionary]=[]
var failures:=0
var metrics:={}
func _initialize() -> void:run.call_deferred()
func check(label:String,passed:bool,value:Variant=null) -> void:
 results.append({"name":label,"passed":passed,"measured":value})
 if not passed:failures+=1
 print("PASS " if passed else "FAIL ",label," ",value)
func frames(count:int,cmd:GameplayCommand=null) -> void:
 arena.injected_command=cmd if cmd!=null else GameplayCommand.new()
 for i in range(count):await physics_frame;await process_frame
func fixture() -> AnimationLibrary:
 var lib:=AnimationLibrary.new()
 var names:=["IDLE_stance","WALK_start","WALK_player","run_player","sprint_civi","Run_stop","Run_stopR","JUMP_launch","JUMP_glide","JUMP_land","CAR_sit","CAR_sitp","CAR_open_LHS","CAR_getin_LHS","CAR_closedoor_LHS","CAR_close_LHS","CAR_getout_LHS","CAR_rollout_LHS","CAR_rollout_RHS","FALL_front","FALL_back","FALL_fall","FALL_glide","FALL_collapse","FALL_land","GETUP_front","GETUP","KO_shot_front","KO_skid_front","KO_skid_back"]
 for prefix in ["BIKEs","BIKEd","BIKEv","BIKEh"]:
  names.append_array([prefix+"_getoffBACK",prefix+"_jumponL",prefix+"_jumponR",prefix+"_Ride",prefix+"_Still",prefix+"_getoffLHS",prefix+"_getoffRHS"])
 for name in names:
  var anim:=Animation.new();anim.length=0.5
  var root_track:=anim.add_track(Animation.TYPE_POSITION_3D);anim.track_set_path(root_track,"Skeleton3D:Root")
  var travel:=0.0
  if name=="sprint_civi":travel=3.0
  elif name=="run_player":travel=2.0
  elif name=="WALK_player":travel=0.75
  elif name=="WALK_start":travel=0.3
  anim.position_track_insert_key(root_track,0,Vector3.ZERO);anim.position_track_insert_key(root_track,0.5,Vector3(0,0,-travel))
  lib.add_animation(name,anim)
 return lib
func until_state(name:String,maximum:=700) -> int:
 for i in range(maximum):
  if arena.transition.state==name:return i
  await frames(1)
 return maximum
func run() -> void:
 arena=preload("res://scenes/arena.tscn").instantiate();arena.test_mode=true;arena.enable_reference_assets=false;root.add_child(arena)
 await frames(90)
 var actor:CharacterMotor=arena.actor
 var car:DriveVehicle=arena.vehicle
 var transition:VehicleTransition=arena.transition
 check("exact stable engine and Jolt",Engine.get_version_info().string.begins_with("4.7.2-stable") and ProjectSettings.get_setting("physics/3d/physics_engine")=="Jolt Physics")
 var state:=ActorSprintState.new();var cmd:=GameplayCommand.new();cmd.sprint=true
 for i in range(300):state.tick(cmd,true,1.0/60)
 check("holding sprint does not manufacture tap boosts",state.active and state.multiplier==1.0)
 var continuous:=true;var maximum:=0.0
 for i in range(360):
  cmd.sprint=i%16<8;state.tick(cmd,true,1.0/60)
  continuous=continuous and state.active;maximum=maxf(maximum,state.multiplier)
 check("repeated sprint presses stay continuous between taps",continuous)
 check("tap boost reaches a strict configurable cap",maximum>1.18 and maximum<=state.profile.maximum_multiplier,maximum)
 cmd.sprint=false
 for i in range(30):state.tick(cmd,true,1.0/60)
 check("sprint release grace expires into ordinary movement",not state.active and state.multiplier==1)
 cmd.sprint=true;state.tick(cmd,false,1.0/60)
 check("ineligible actions discard sprint boost",not state.active and state.multiplier==1)
 actor.configure_reference(ImportedGameplayDatabase.new(),"STAT_PLAYER",fixture())
 actor.respawn(Vector3(-25,0.94,45));actor.facing=0;await frames(30)
 cmd=GameplayCommand.new();cmd.move=Vector2(0,-1);cmd.sprint=true;await frames(60,cmd)
 var no_stop:=true;var low:=INF;var high:=0.0
 for i in range(360):
  cmd.sprint=i%16<8;await frames(1,cmd)
  var speed:=Vector2(actor.velocity.x,actor.velocity.z).length()
  low=minf(low,speed);high=maxf(high,speed)
  no_stop=no_stop and actor.reference_motion.clip=="sprint_civi"
 metrics.sprint={"minimum_mps":low,"maximum_mps":high,"cap_multiplier":actor.sprint.profile.maximum_multiplier}
 check("tapping preserves the sprint clip and never restarts locomotion",no_stop and low>5.9,metrics.sprint)
 check("gait playback and motor speed share the capped tap multiplier",high>7.0 and high<=7.21,high)
 var m:=actor.reference_motion;m.phase="stop";m.set_clip("Run_stop");m.time=0.1
 var delta:=m.step(1,true,false,1.0/60)
 check("renewed movement interrupts a lingering run-stop",m.phase=="move" and not m.heading_locked and delta.length()>0)
 actor.respawn(car.approach_position()+Vector3(-0.9,0,0.4));actor.facing=0;await frames(35)
 var from:=actor.global_position
 check("entry initially reserves without disabling the standing collider",transition.request_enter(car) and transition.state=="approaching" and actor.control_enabled and actor.collision_layer!=0 and car.driver==null)
 await frames(1)
 check("walk-in keeps the door closed before arrival",not car.doors[0].opened and transition.state=="approaching")
 var traveled:=0.0;var last:=actor.global_position;var max_step:=0.0
 for i in range(600):
  if transition.state!="approaching":break
  await frames(1)
  traveled+=actor.global_position.distance_to(last);max_step=maxf(max_step,actor.global_position.distance_to(last));last=actor.global_position
 check("automatic entry physically walks to the approach marker",transition.state=="entering" and traveled>0.6 and max_step<0.12,{"distance":traveled,"maximum_tick_displacement":max_step,"state":transition.state})
 await until_state("driving")
 check("only mounting commits unique driver ownership",transition.state=="driving" and car.driver==actor and car.reservation==null and not actor.control_enabled)
 transition.request_exit();await until_state("on_foot");await frames(30)
 check("walk-in entry preserves the continuous enter-drive-exit loop",actor.control_enabled and car.driver==null)
 actor.respawn(car.global_position+Vector3(0,0.35,-2.8));actor.facing=0;await frames(35)
 var planned:=transition.request_enter(car)
 check("approach planner can route around the chassis from the front",planned and transition.approach.points.size()>=2,transition.approach.points.size())
 if planned:await until_state("driving")
 check("corner route reaches and mounts without teleporting through the car",transition.state=="driving",transition.message)
 if transition.state=="driving":transition.request_exit();await until_state("on_foot")
 elif transition.state!="on_foot":transition.recover()
 actor.respawn(car.approach_position()+Vector3(-0.7,0,0.3));await frames(35)
 transition.request_enter(car);await frames(4);var cancellation:=actor.global_position
 transition.cancel_approach("cancelled")
 check("cancelling approach releases the seat at the current physical position",actor.control_enabled and car.reservation==null and transition.state=="on_foot" and actor.global_position.distance_to(cancellation)<0.001)
 actor.respawn(car.approach_position()+Vector3(-0.7,0,0.3));await frames(35)
 transition.request_enter(car);car.seating.release(actor);await frames(1)
 check("lost reservations cancel approach without duplicate control",transition.state=="on_foot" and actor.control_enabled)
 actor.respawn(car.approach_position()+Vector3(-0.7,0,0.3));await frames(35)
 transition.request_enter(car);actor.health.receive(10000);await frames(1)
 check("death while approaching releases reservation without moving the corpse into a seat",transition.state=="on_foot" and car.reservation==null and not actor.control_enabled)
 actor.respawn(car.approach_position()+Vector3(-0.7,0,0.3));await frames(35)
 transition.request_enter(car)
 var obstruction:=LabGeometry.box(arena,Vector3(0.25,3,4),actor.global_position+Vector3(0.35,0,0),Color.GRAY,true)
 await frames(140)
 check("new obstacles cancel a stalled approach while preserving collision and occupancy",transition.state=="on_foot" and actor.control_enabled and car.reservation==null,transition.message)
 obstruction.queue_free();await frames(2)
 actor.respawn(car.approach_position()+Vector3(-0.7,0,0.3));await frames(35)
 transition.request_enter(car);car.damage.state="destroyed";await frames(1)
 check("destroyed vehicles cancel the walk-in transaction",transition.state=="on_foot" and car.reservation==null and actor.control_enabled)
 car.damage.repair()
 actor.respawn(Vector3(-20,2,35));actor.facing=0;actor.actions.begin_life("down");actor.control_enabled=false
 actor.reaction_body.launch_velocity(actor.global_position,0,Vector3(3,0,-3))
 var saw_rest:=false;var saw_getup:=false
 for i in range(500):
  await frames(1)
  saw_rest=saw_rest or actor.reaction_body.rest.locked
  if actor.actions.life=="getting_up":
   saw_getup=true
   check("prone reactions choose a face-down get-up clip",actor.actions.life_clip=="GETUP_front",actor.actions.life_clip)
   break
 check("get-up waits for quiet supported settling",saw_rest and saw_getup)
 await frames(100)
 check("recovered heading follows the direction of the fall",actor.control_enabled and absf(angle_difference(actor.facing,PI*-0.25))<0.05,actor.facing)
 car.freeze=true;car.kind="bike";car.bike_animation="BIKEs"
 actor.respawn(car.approach_position());car.reserve_seat(actor);car.commit_seat(actor);actor.set_embarked(true)
 transition.vehicle=car;transition.seat_index=0;transition.state="driving"
 var bailed:=transition.request_eject()
 check("bike bailout chooses the model-specific rear exit and rear animation",bailed and transition.escape_clip=="BIKEs_getoffBACK" and car.to_local(transition.exit_position).z>0,{"clip":transition.escape_clip,"exit_index":transition.exit_index})
 await frames(5)
 check("bike rear get-off has its own mount-release windup",transition.state=="ejecting" and car.driver==actor)
 await frames(16)
 check("bike bailout releases once into the physical reaction body",transition.state=="on_foot" and car.driver==null and actor.reaction_body.active)
 car.kind="car";car.freeze=false
 # Rest is presentation-only and must never damp airborne or sliding motion.
 var rest:=ReactionRestState.new();rest.begin(0,Vector3.FORWARD*8)
 for i in range(180):rest.observe(false,Vector3.ZERO,Vector3.ZERO,Basis.IDENTITY,1.0/60)
 check("no settling correction is allowed while airborne",not rest.locked and rest.weight==0)
 for i in range(180):rest.observe(true,Vector3(3,0,0),Vector3.ZERO,Basis.IDENTITY,1.0/60)
 check("sliding bodies preserve their physical orientation",not rest.locked and rest.weight==0)
 for i in range(40):rest.observe(true,Vector3.ZERO,Vector3.ZERO,Basis.IDENTITY,1.0/60)
 check("forward falls settle prone only after continuous quiet contact",rest.locked and rest.face_down and rest.weight==1)
 rest.begin(0,Vector3.BACK*8)
 for i in range(40):rest.observe(true,Vector3.ZERO,Vector3.ZERO,Basis.IDENTITY,1.0/60)
 check("backward falls settle belly up with a consistent heading",rest.locked and not rest.face_down and absf(angle_difference(rest.heading,0))<0.01)
 rest.observe(true,Vector3(3,0,0),Vector3.ZERO,Basis.IDENTITY,1.0/60)
 check("a new impact unlocks the settled presentation",not rest.locked)
 for direction in [Vector3.FORWARD,Vector3.BACK]:
  actor.respawn(Vector3(-20,3,35));actor.facing=0;actor.health.receive(10000)
  actor.reaction_body.launch_velocity(actor.global_position,0,direction*4)
  await frames(20)
  check("Jolt reaction remains spinning before support "+str(direction),actor.reaction_body.active and not actor.reaction_body.rest.locked and actor.reaction_body.rest.weight==0)
  await frames(260)
  check("landed quiet corpse chooses the matching face orientation "+str(direction),actor.reaction_body.rest.locked and actor.reaction_body.rest.face_down==(direction==Vector3.FORWARD) and actor.visual.global_basis.y.dot(Vector3.UP)>0.99,{"locked":actor.reaction_body.rest.locked,"clip":actor.actions.life_clip,"angular":actor.reaction_body.angular_velocity.length()})
 actor.respawn(Vector3(-25,12,35));var landing_count:=actor.fall.landing_events;await frames(50)
 check("long on-foot falls transfer motion to the Jolt reaction body",actor.reaction_body.active and actor.reaction_body.tumble_fall)
 await frames(200)
 check("physical fall landing dispatches environmental damage once",actor.fall.landing_events==landing_count+1 and actor.fall.last_damage>0,{"damage":actor.fall.last_damage,"health":actor.health.health})
 for prefix in ["BIKEs","BIKEd","BIKEv","BIKEh"]:
  var variant:=VehicleVariant.new()
  check("intentional bike bailout selects rear get-off for "+prefix,variant.bailout_clip(prefix,actor.actions)==prefix+"_getoffBACK")
 var report:={"engine":Engine.get_version_info().string,"backend":"Jolt Physics","assertions":results.size(),"failures":failures,"results":results,"metrics":metrics,"assets":"synthetic clips and primitive models; native converted assets unavailable after workspace maintenance","native_visual_validation":false}
 var file:=FileAccess.open("res://tests/intent_revision_results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("RESULT intent revision ",results.size()," / failures ",failures)
 arena.queue_free();await process_frame;quit(1 if failures else 0)
