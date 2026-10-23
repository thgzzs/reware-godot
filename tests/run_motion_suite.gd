extends SceneTree
## Temporal tests use the actual imported skin, not just selected clip names.
var arena: Node3D
var results: Array[Dictionary] = []
var metrics := {}
var failures := 0
var capture := false
func _initialize() -> void: run.call_deferred()
func frames(count: int, cmd: GameplayCommand = null) -> void:
 arena.injected_command = cmd if cmd!=null else GameplayCommand.new()
 for i in range(count):
  await physics_frame
  await process_frame
func check(label: String, condition: bool, value: Variant = null) -> void:
 results.append({"name":label,"passed":condition,"measured":value})
 if not condition: failures += 1
 print("PASS " if condition else "FAIL ",label," ",value)
func image_at(label: String, eye: Vector3, target: Vector3) -> void:
 if not capture: return
 arena.rig.camera.global_position = eye
 arena.rig.camera.look_at(target)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/motion-"+label+".png")
func run() -> void:
 capture = DisplayServer.get_name()!="headless"
 arena = preload("res://scenes/arena.tscn").instantiate()
 arena.test_mode = true
 root.add_child(arena)
 await frames(90)
 var actor: CharacterMotor = arena.actor
 var visual := actor.reference_pose as SkinnedMotionVisual
 if visual==null: push_error("Imported skin required for motion validation"); quit(2); return
 var thigh := visual.skeleton.find_bone("R Thigh")
 var hand := visual.skeleton.find_bone("R Hand")
 for slot in range(actor.weapon.inventory.size()):
  actor.weapon.equip_slot(slot)
  actor.respawn(Vector3(-28,0.94,40))
  await frames(25)
  var sprint := GameplayCommand.new(); sprint.move = Vector2(0,-1); sprint.sprint = true
  await frames(65,sprint)
  var first := visual.skeleton.get_bone_pose_rotation(thigh)
  await image_at("sprint-a",actor.global_position+Vector3(-3,1.1,-2.5),actor.global_position)
  await frames(10,sprint)
  var change := first.angle_to(visual.skeleton.get_bone_pose_rotation(thigh))
  check("sprint thigh moves over time in slot %d"%slot,change>0.15 and actor.drive_velocity.length()>3,change)
  await image_at("sprint-b",actor.global_position+Vector3(-3,1.1,-2.5),actor.global_position)
  # Reproduce jumping from ordinary run, the stale walk/run-layer failure.
  sprint.sprint = false
  await frames(35,sprint)
  sprint.jump = true; await frames(1,sprint); sprint.jump = false
  var saw_launch := false
  var saw_glide := false
  var saw_land := false
  var base_y := actor.global_position.y
  var maximum_y := base_y
  var jump_first := visual.skeleton.get_bone_pose_rotation(thigh)
  var motion_change := 0.0
  var selected_exclusively := true
  for i in range(100):
   await frames(1,sprint)
   maximum_y = maxf(maximum_y,actor.global_position.y)
   motion_change = maxf(motion_change,jump_first.angle_to(visual.skeleton.get_bone_pose_rotation(thigh)))
   var phase: String = actor.phase
   if phase in ["launch","airborne","landing"]:
    var layers := actor.reference_motion.pose_layers()
    selected_exclusively = selected_exclusively and layers.size()==1 and layers[0].clip.begins_with("JUMP_")
    check_upper_block(actor)
   if phase=="launch": saw_launch = true
   if phase=="airborne": saw_glide = true
   if phase=="landing": saw_land = true
   if i==16 and slot==0: await image_at("jump",actor.global_position+Vector3(-3,1.1,-2.5),actor.global_position)
  check("run jump owns visible pose and completes in slot %d"%slot,saw_launch and saw_glide and saw_land and selected_exclusively and motion_change>0.3 and maximum_y-base_y>0.5,{"rise":maximum_y-base_y,"bone_delta":motion_change,"exclusive_layers":selected_exclusively})
 actor.weapon.equip_slot(0)
 actor.respawn(Vector3(-28,0.94,40));await frames(25)
 var aim := GameplayCommand.new(); aim.aim = true; aim.move = Vector2(0.4,-0.5)
 for pitch in [-0.35,0.0,0.4]:
  arena.rig.pitch = pitch
  await frames(25,aim)
  var pose := visual.skeleton.global_transform*visual.skeleton.get_bone_global_pose(hand)
  var desired: Vector3 = (actor.actions.aim_target-pose.origin).normalized()
  var error := pose.basis.x.normalized().angle_to(desired)
  check("world gun axis converges on camera-center target pitch %.2f"%pitch,error<0.04,error)
 aim.fire = true; await frames(1,aim);aim.fire=false
 await frames(2,aim)
 check("fire produces a recoil envelope",actor.actions.firing_left>0 and actor.actions.aim_weight>0.9)
 await image_at("aim",actor.global_position+Vector3(-2,0.8,-2),actor.global_position+Vector3(0,0.25,0))
 actor.weapon.magazine = 1
 aim.reload=true;await frames(1,aim);aim.reload=false
 await frames(maxi(2,ceili(actor.weapon.profile.reload_seconds*60*0.15)),aim)
 var reload_a := visual.skeleton.get_bone_global_pose(hand).origin
 await frames(maxi(2,ceili(actor.weapon.profile.reload_seconds*60*0.35)),aim)
 var reload_delta := reload_a.distance_to(visual.skeleton.get_bone_global_pose(hand).origin)
 check("reload is a changing upper pose while legs still move",reload_delta>0.02 and actor.drive_velocity.length()>0.1,reload_delta)
 await image_at("reload",actor.global_position+Vector3(-2,0.8,-2),actor.global_position+Vector3(0,0.25,0))
 await frames(90)
 var car: DriveVehicle = arena.vehicle
 car.reset_at(Vector3(18,0.9,25));await frames(100)
 actor.reset_at(car.approach_position());await frames(25)
 check("entry begins",arena.transition.request_enter(car))
 await frames(ceili(arena.transition.profile.enter_seconds*60)+20)
 var pelvis := visual.skeleton.find_bone("Pelvis")
 var hip: Vector3 = visual.skeleton.global_transform*visual.skeleton.get_bone_global_pose(pelvis).origin
 var seat_error := hip.distance_to(car.seat_position())
 check("driver remains visible with pelvis on seat anchor",actor.visible and arena.transition.state=="driving" and seat_error<0.025,seat_error)
 var fit := true
 for name in ["L Calf","R Calf","L Foot","R Foot","Head"]:
  var bone := visual.skeleton.find_bone(name)
  var local := car.to_local(visual.skeleton.global_transform*visual.skeleton.get_bone_global_pose(bone).origin)
  fit = fit and absf(local.x)<0.70 and local.y<0.65
 check("seated limbs fit inside cabin and door finishes closing",fit and car.doors[0].latched)
 await image_at("seat",car.global_position+Vector3(-2.6,1.6,-1.4),car.seat_position()+Vector3(0,0.15,0))
 var drive := GameplayCommand.new();drive.move = Vector2(0,-1)
 await frames(60,drive)
 var hub := car.wheel_spinners[0].get_node("Hub") as Node3D
 var hub_before := hub.global_basis
 var phase_before: float = car.wheel_angles[0]
 await frames(7,drive)
 check("visible hub rotates with forward travel",hub_before.x.angle_to(hub.global_basis.x)+hub_before.y.angle_to(hub.global_basis.y)>0.15 and absf(car.wheel_angles[0]-phase_before)>0.1,car.wheel_angles[0]-phase_before)
 var stop := GameplayCommand.new();stop.brake=true;await frames(150,stop)
 var reverse := GameplayCommand.new();reverse.move=Vector2(0,1);await frames(65,reverse)
 var reverse_angle: float = car.wheel_angles[0]
 await frames(1,reverse)
 check("wheel axle rolls backward during reverse",car.speed< -0.3 and wrapf(car.wheel_angles[0]-reverse_angle,-PI,PI)>0,{"speed":car.speed,"delta":wrapf(car.wheel_angles[0]-reverse_angle,-PI,PI)})
 await frames(150,stop)
 check("exit begins",arena.transition.request_exit())
 await frames(ceili(arena.transition.profile.exit_seconds*60)+25)
 check("exit restores controllable actor",arena.transition.state=="on_foot" and actor.control_enabled)
 # Isolate the actual chassis/probe/Jolt solve from the player-input loop.
 arena.set_physics_process(false)
 for brain in arena.ped_brains: brain.set_physics_process(false)
 car.reset_at(Vector3(18,0.9,25));await frames(100)
 actor.respawn(Vector3(-28,0.94,40))
 var ped: CharacterMotor = arena.pedestrians[0]
 ped.respawn(Vector3(18,0.94,20.6))
 for i in range(25):ped.tick(GameplayCommand.new(),0,1.0/60);await frames(1)
 car.brake=0;car.throttle=0;car.linear_velocity=Vector3(0,0,-10)
 var start := ped.global_position
 var highest := start.y
 var contacted := false
 for i in range(150):
  ped.tick(GameplayCommand.new(),0,1.0/60)
  await frames(1)
  highest = maxf(highest,ped.reaction_body.global_position.y if ped.reaction_body.active else ped.global_position.y)
  if ped.reaction_body.vehicle_contacts>0: contacted=true
  if i in [12,25,45] and ped.reaction_body.active:await image_at("impact-%d"%i,car.global_position+Vector3(-5,2,-1),ped.reaction_body.global_position)
 metrics.impact={"health":ped.health.health,"displacement":ped.global_position.distance_to(start),"lift":highest-start.y,"car_contacts":ped.reaction_body.vehicle_contacts,"contact_ticks":ped.reaction_body.contact_ticks,"speed":ped.reaction_velocity.length()}
 check("moderate impact survives and physically contacts car",ped.health.health>0 and contacted and ped.reaction_body.contact_ticks>0,metrics.impact)
 check("Jolt impact transfers momentum and lifts the torso",ped.global_position.distance_to(start)>1 and highest-start.y>0.4,metrics.impact)
 car.brake = 1
 for i in range(420):ped.tick(GameplayCommand.new(),0,1.0/60);await frames(1)
 check("nonfatal proxy safely returns to standing control",ped.control_enabled and ped.actions.life=="alive" and not ped.reaction_body.active,{"life":ped.actions.life,"position":ped.global_position})
 metrics.orchestration = arena.telemetry.summary()
 metrics.wheel_forces = car.force_telemetry.summary()
 var file := FileAccess.open("res://tests/motion_results.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"backend":"Jolt Physics","results":results,"failures":failures,"metrics":metrics,"reference_runtime_parity":false},"  "));file.close()
 print("RESULT motion ",results.size()," / failures ",failures)
 arena.queue_free();await process_frame;quit(1 if failures else 0)
func check_upper_block(actor: CharacterMotor) -> void:
 if actor.actions.upper_allowed:
  failures += 1
  print("FAIL jump overlay priority")
