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
func recovery_for(actor:CharacterMotor) -> ActorSpawnRecovery:
 for child in actor.get_children():
  if child is ActorSpawnRecovery:return child
 return null
func board(bike:DriveVehicle) -> void:
 var actor:CharacterMotor=arena.actor
 bike.reserve_seat(actor,0);bike.commit_seat(actor,0);actor.set_embarked(true)
 arena.transition.vehicle=bike;arena.transition.seat_index=0;arena.transition.state="driving"
func run() -> void:
 arena=load("res://scenes/arena.tscn").instantiate();arena.test_mode=true;root.add_child(arena);await frames(100)
 for brain in arena.ped_brains:brain.set_physics_process(false)
 var ped:CharacterMotor=arena.pedestrians[0]
 var recovery:=recovery_for(ped);recovery.profile=recovery.profile.duplicate();recovery.profile.death_delay=0.5
 var same_id:=ped.get_instance_id();var brain:PedBrain=arena.ped_brains[0]
 brain.state="fight";brain.aggressor=arena.actor;brain.pursuit_left=10
 ped.receive_damage(10000,ped.global_position,Vector3.FORWARD)
 await frames(15)
 check("death remains visible before configured delay",ped.health.health<=0 and recovery.recoveries==0)
 await frames(25)
 check("dead pedestrian respawns once on its original mark",ped.health.health==ped.health.max_health and ped.global_position.distance_to(recovery.spawn_position)<0.1 and recovery.recoveries==1,ped.global_position)
 check("respawn reuses the same shared character instance",ped.get_instance_id()==same_id)
 check("respawn restores motor collision, visibility and life",ped.visible and ped.control_enabled and ped.actions.life=="alive" and ped.collision_layer==10 and not ped.corpse_hitbox.active and not ped.reaction_body.active)
 check("respawn clears AI threat and combat pursuit",brain.state=="wander" and brain.aggressor==null and brain.pursuit_left==0)
 await frames(40)
 check("living pedestrian does not continuously reset",recovery.recoveries==1)
 ped.reset_at(Vector3(-50,-20,0));await frames(3)
 check("living pedestrian returns from the void",ped.health.health>0 and ped.global_position.distance_to(recovery.spawn_position)<0.15 and recovery.recoveries==2)
 ped.receive_damage(10000,ped.global_position,Vector3.FORWARD)
 ped.reaction_body.launch_velocity(Vector3(-50,-20,0),0,Vector3.DOWN*10)
 await frames(3)
 check("dead physical reaction also recovers immediately from the void",ped.health.health>0 and not ped.reaction_body.active and recovery.recoveries==3)
 var blocker:=LabGeometry.box(arena,Vector3(1.4,2,1.4),recovery.spawn_position,Color.GRAY,true);await frames(2)
 var alternative:=recovery.safe_spawn()
 check("blocked spawn chooses a clear nearby floor position",alternative.is_finite() and alternative.distance_to(recovery.spawn_position)>1 and alternative.distance_to(recovery.spawn_position)<4 and absf(alternative.y-recovery.spawn_position.y)<0.2,alternative)
 blocker.queue_free();await frames(2)
 var player:CharacterMotor=arena.actor
 player.receive_damage(10000,player.global_position,Vector3.FORWARD)
 player.reset_at(Vector3(50,-25,0));await frames(3)
 check("player void return restores health and controls",player.health.health==player.health.max_health and player.control_enabled and player.visible and player.global_position.distance_to(arena.player_spawn.spawn_position)<0.15)
 check("player turning is moderately faster without changing AI tuning",is_equal_approx(player.profile.running_turn_rate,ped.profile.running_turn_rate*player.profile.player_turn_multiplier) and is_equal_approx(player.profile.standing_turn_rate,ped.profile.standing_turn_rate*player.profile.player_turn_multiplier),player.profile.running_turn_rate)
 var bike:DriveVehicle=arena.get_node("pcj600")
 board(bike);bike.global_position=Vector3(45,-22,0);player.global_position=bike.global_position
 await frames(5)
 check("mounted void return clears both seat and controller ownership",arena.transition.state=="on_foot" and arena.transition.vehicle==null and bike.driver==null and bike.seating.reservations.is_empty() and player.visible and player.control_enabled)
 await frames(100)
 check("vehicle returns to its own spawn mark",bike.global_position.distance_to(bike.spawn_position)<0.7,bike.global_position)
 # Isolated flat-ground cornering: no walls, direct initial speed, actual Jolt forces.
 for side in [-1.0,1.0]:
  arena.transition.abort_for_respawn();player.respawn(arena.player_spawn.spawn_position)
  bike.reset_at(Vector3(-48,0.75,40));await frames(90);board(bike)
  bike.linear_velocity=Vector3(0,0,-9)
  var cmd:=GameplayCommand.new();cmd.move=Vector2(side,0)
  var inward:=0.0;var error:=0.0;var measured:=0.0;var samples:=0
  for i in range(90):
   await frames(1,cmd)
   if i>40:
    var bank:=atan2(bike.global_basis.x.dot(Vector3.UP),bike.global_basis.y.dot(Vector3.UP))
    inward+=bank*side;error+=absf(bank-bike.bike.lean);measured=bank;samples+=1
  check("bike banks into "+("left"if side<0 else"right")+" turn without rider loss",inward/samples< -0.03 and arena.transition.state=="driving" and error/samples<0.13,{"bank_rad":measured,"tracking_error_rad":error/samples,"state":arena.transition.state})
  await frames(180)
  var residual:=absf(atan2(bike.global_basis.x.dot(Vector3.UP),bike.global_basis.y.dot(Vector3.UP)))
  check("bike straightens after "+("left"if side<0 else"right")+" steering is released",residual<0.05 and absf(bike.bike.lean)<0.01 and arena.transition.state=="driving",residual)
  arena.transition.abort_for_respawn()
 var report:={"engine":Engine.get_version_info().string,"assertions":results.size(),"failures":failures,"results":results,"android_device_tested":false}
 var f:=FileAccess.open("res://tests/recovery_results.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("RESULT recovery ",results.size()," / failures ",failures)
 arena.queue_free();await process_frame;quit(1 if failures else 0)
