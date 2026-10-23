extends SceneTree
var arena: Node3D
var results: Array[Dictionary]=[]
var failures:=0
func _initialize() -> void:run.call_deferred()
func frames(count:int,cmd:GameplayCommand=null) -> void:
 arena.injected_command=cmd if cmd!=null else GameplayCommand.new()
 for i in range(count):await physics_frame;await process_frame
func check(label:String,passed:bool,value:Variant=null) -> void:
 results.append({"name":label,"passed":passed,"measured":value})
 if not passed:failures+=1
 print("PASS " if passed else "FAIL ",label," ",value)
func run() -> void:
 arena=preload("res://scenes/arena.tscn").instantiate();arena.test_mode=true;arena.enable_vehicle_fixtures=false;root.add_child(arena)
 await frames(90)
 var actor:CharacterMotor=arena.actor
 var car:DriveVehicle=arena.vehicle
 var launch_speeds:=[]
 for mode in ["stationary","walk-start","walk","run","sprint"]:
  actor.respawn(Vector3(-28,0.94,38));actor.facing=0;actor.visual.rotation.y=0
  await frames(25)
  var cmd:=GameplayCommand.new()
  if mode!="stationary":cmd.move=Vector2(0,-1)
  cmd.walk=mode in ["walk-start","walk"]
  cmd.sprint=mode=="sprint"
  if mode=="walk-start":await frames(1,cmd)
  elif mode!="stationary":await frames(60,cmd)
  var before_speed:=Vector2(actor.drive_velocity.x,actor.drive_velocity.z).length()
  cmd.jump=true;await frames(1,cmd);cmd.jump=false
  for i in range(15):
   await frames(1,cmd)
   if actor.jump_count>0 and actor.phase=="airborne":break
  var speed:=Vector2(actor.drive_velocity.x,actor.drive_velocity.z).length()
  launch_speeds.append(speed)
  check(mode+" jump has source-dependent forward momentum",actor.phase=="airborne" and speed>=4.99 and speed<=maxf(11.0,before_speed)+0.01,{"phase":actor.phase,"speed":speed})
 check("run and sprint jumps are not forced to the same velocity",launch_speeds[3]>launch_speeds[2]+1 and launch_speeds[4]>launch_speeds[3]+1,launch_speeds)
 var ramp:=LabGeometry.box(arena,Vector3(3,0.2,6),Vector3(-28,0.85,-30),Color.GRAY,true);ramp.rotation.x=deg_to_rad(15)
 actor.respawn(Vector3(-28,0.94,-26));actor.facing=0;await frames(25)
 var run_cmd:=GameplayCommand.new();run_cmd.move=Vector2(0,-1)
 var highest:=actor.global_position.y
 for i in range(90):await frames(1,run_cmd);highest=maxf(highest,actor.global_position.y)
 check("walkable uphill slope gains only terrain height",highest>1.6 and highest<3.2,highest)
 actor.respawn(Vector3(-28,2.3,-32.2));actor.facing=PI;actor.visual.rotation.y=PI
 await frames(25)
 run_cmd.move=Vector2(0,1);run_cmd.sprint=true
 await frames(15,run_cmd);run_cmd.jump=true;await frames(1,run_cmd);run_cmd.jump=false
 highest=actor.global_position.y
 for i in range(100):await frames(1,run_cmd);highest=maxf(highest,actor.global_position.y)
 check("downhill running/jumping leaves the slope without sticking",actor.global_position.z> -25 and actor.global_position.y<1.2 and highest<4.0,{"at":actor.global_position,"max_y":highest})
 ramp.queue_free();await frames(2)
 var wedge:=LabGeometry.box(arena,Vector3(3,0.2,6),Vector3(-28,1.4,-12),Color.GRAY,true);wedge.rotation.x=deg_to_rad(55)
 actor.respawn(Vector3(-28,0.94,-8));actor.facing=0;actor.visual.rotation.y=0;await frames(25)
 run_cmd.move=Vector2(0,-1)
 highest=actor.global_position.y
 var max_speed:=0.0
 for i in range(300):
  run_cmd.jump=i%50==0
  await frames(1,run_cmd)
  highest=maxf(highest,actor.global_position.y)
  max_speed=maxf(max_speed,actor.velocity.length())
 check("steep wedge cannot accumulate upward launch energy",highest<3.5 and max_speed<16,{"max_y":highest,"speed":max_speed,"at":actor.global_position})
 wedge.queue_free();await frames(2)
 car.damage.repair();car.reset_at(Vector3(18,0.9,10));await frames(90)
 actor.reset_at(Vector3(18,0.94,14.1));actor.facing=0;actor.visual.rotation.y=0;await frames(25)
 var before:=car.global_position
 run_cmd.jump=false;run_cmd.move=Vector2(0,-1)
 await frames(180,run_cmd)
 check("ordinary movement does not shove a heavy parked vehicle",Vector2(car.global_position.x-before.x,car.global_position.z-before.z).length()<0.15,{"movement":car.global_position-before,"speed":car.linear_velocity.length()})
 # Re-hit an already knocked-down body through real Jolt contact.
 arena.set_physics_process(false)
 for brain in arena.ped_brains:brain.set_physics_process(false)
 var ped:CharacterMotor=arena.pedestrians[1]
 ped.respawn(Vector3(18,0.94,-10));ped.reaction_body.profile=ped.reaction_body.profile.duplicate();ped.reaction_body.profile.recovery_delay=100
 car.reset_at(Vector3(18,0.9,25));await frames(50)
 ped.receive_vehicle_impact(car,2.1,Vector3.FORWARD)
 for i in range(80):ped.tick(GameplayCommand.new(),0,1.0/60);await frames(1)
 var old_health:=ped.health.health
 var torso:=ped.reaction_body.global_position
 car.reset_at(Vector3(torso.x,0.9,torso.z+4.2));await frames(2)
 car.brake=0;car.linear_velocity=Vector3(0,0,-12)
 for i in range(90):ped.tick(GameplayCommand.new(),0,1.0/60);await frames(1)
 check("fresh collision damages an already active knockdown",ped.health.health<old_health and ped.reaction_body.repeated_hits>0,{"before":old_health,"after":ped.health.health,"fresh_hits":ped.reaction_body.repeated_hits,"contacts":ped.reaction_body.vehicle_contacts,"closing":ped.reaction_body.maximum_contact_speed,"normal":ped.reaction_body.last_contact_normal,"age":ped.reaction_body.age})
 old_health=ped.health.health
 car.brake=1
 for i in range(60):ped.tick(GameplayCommand.new(),0,1.0/60);await frames(1)
 check("sustained resting contact does not drain pedestrian health",is_equal_approx(ped.health.health,old_health),{"before":old_health,"after":ped.health.health})
 # A later severe strike must still kill an already-down actor.
 car.reset_at(Vector3(18,0.9,30));await frames(3)
 for i in range(70):ped.tick(GameplayCommand.new(),0,1.0/60);await frames(1)
 torso=ped.reaction_body.global_position
 car.reset_at(Vector3(torso.x,0.9,torso.z+4.2));await frames(2)
 car.brake=0;car.linear_velocity=Vector3(0,0,-24)
 for i in range(140):ped.tick(GameplayCommand.new(),0,1.0/60);await frames(1)
 check("subsequent severe impact can kill a downed pedestrian",ped.health.health<=0 and ped.actions.life in ["dying","dead"],{"health":ped.health.health,"life":ped.actions.life,"fresh_hits":ped.reaction_body.repeated_hits})
 var f:=FileAccess.open("res://tests/foundation_results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"assertions":results.size(),"failures":failures,"results":results,"reference_runtime_parity":false},"  "));f.close()
 print("RESULT foundation ",results.size()," assertions / ",failures," failures")
 arena.queue_free();await process_frame;quit(1 if failures else 0)
