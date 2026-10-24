extends SceneTree
## Real Jolt integration tests. Run with --fixed-fps 60 for one tick per frame.
var arena: Node3D
var results: Array[Dictionary] = []
var metrics := {}
var failures := 0
func _initialize() -> void:
 run.call_deferred()
func frames(count: int, command: GameplayCommand = null) -> void:
 arena.injected_command = command if command != null else GameplayCommand.new()
 for i in range(count):
  await physics_frame
  await process_frame
func check(name: String, condition: bool, measured: Variant = null) -> void:
 results.append({"name":name,"passed":condition,"measured":measured})
 if not condition: failures += 1
 print("PASS " if condition else "FAIL ",name," ",measured)
func place_actor(p: Vector3) -> void:
 arena.actor.reset_at(p)
 arena.actor.facing=0;arena.actor.visual.rotation.y=0
 arena.rig.yaw = 0
 arena.rig.pitch = 0.12
 arena.rig.initialized = false
 await frames(20)
func run() -> void:
 arena = preload("res://scenes/arena.tscn").instantiate()
 arena.test_mode = true
 arena.enable_reference_assets = false
 root.add_child(arena)
 await frames(120)
 var actor: CharacterMotor = arena.actor
 var car: DriveVehicle = arena.vehicle
 var seat: VehicleTransition = arena.transition
 var gun: WeaponController = arena.weapon
 check("exact engine",Engine.get_version_info().string.begins_with("4.7.2-stable"),Engine.get_version_info().string)
 check("Jolt selected",ProjectSettings.get_setting("physics/3d/physics_engine")=="Jolt Physics")
 check("ground support",actor.grounded,actor.global_position.y)
 await place_actor(Vector3(-28,0.94,30))
 var walk := GameplayCommand.new()
 walk.move = Vector2(0,-1)
 var start := actor.global_position
 await frames(60,walk)
 check("movement accelerates to configured speed",absf(actor.velocity.length()-actor.profile.speed)<0.12,actor.velocity.length())
 check("movement distance in one second",start.distance_to(actor.global_position)>4.0 and start.distance_to(actor.global_position)<5.2,start.distance_to(actor.global_position))
 await frames(20)
 check("release decelerates to rest",actor.velocity.length()<0.03,actor.velocity.length())
 await place_actor(Vector3(-28,0.94,30))
 arena.rig.yaw = PI/2
 var old := actor.global_position
 await frames(60,walk)
 check("camera relative forward follows a bounded turning arc",actor.global_position.x<old.x-3.0 and absf(actor.global_position.z-old.z)<1.5 and absf(angle_difference(actor.facing,PI/2))<0.01,actor.global_position-old)
 await place_actor(Vector3(-28,0.94,30))
 var aim_walk := GameplayCommand.new()
 aim_walk.aim = true
 aim_walk.move = Vector2(0,-1)
 await frames(45,aim_walk)
 check("aim movement modifier",absf(actor.velocity.length()-actor.profile.speed*actor.profile.aim_multiplier)<0.1,actor.velocity.length())
 check("aim FOV converges",absf(arena.rig.camera.fov-arena.rig.profile.aim_fov)<0.1,arena.rig.camera.fov)
 await frames(20)
 var jump := GameplayCommand.new()
 jump.jump = true
 var base := actor.global_position.y
 var jump_start_tick: int = arena.tick_number
 await frames(1,jump)
 var launch_tick := -1
 var land_tick := -1
 var apex := base
 var old_landings := actor.landing_count
 for i in range(100):
  await frames(1)
  if launch_tick<0 and actor.velocity.y>0.5: launch_tick = arena.tick_number
  apex = maxf(apex,actor.global_position.y)
  if actor.landing_count>old_landings:
   land_tick = arena.tick_number
   break
 metrics.jump = {"launch_delay_s":(launch_tick-jump_start_tick)/60.0,"apex_m":apex-base,"airborne_s":(land_tick-launch_tick)/60.0}
 check("jump launches after windup",launch_tick-jump_start_tick>=7 and launch_tick-jump_start_tick<=10,metrics.jump)
 check("jump apex within ballistic tolerance",apex-base>1.0 and apex-base<1.25,apex-base)
 check("jump lands and recovers",land_tick>launch_tick and actor.grounded,land_tick)
 await frames(15)
 check("landing state clears",actor.phase=="grounded",actor.phase)
 # A press shortly before landing must survive until support returns.
 actor.reset_at(Vector3(-28,1.0,30))
 actor.velocity = Vector3(0,-2,0)
 await frames(1,jump)
 var prior_jumps := actor.jump_count
 await frames(18)
 check("buffered press launches on landing",actor.jump_count>prior_jumps,actor.jump_count-prior_jumps)
 await place_actor(Vector3(-8,0.94,12))
 var backward := GameplayCommand.new()
 backward.move = Vector2(0,1)
 await frames(60,backward)
 check("wall collision prevents tunneling",actor.global_position.z<13.51,actor.global_position.z)
 await place_actor(Vector3(-15,0.94,14))
 await frames(1,jump)
 var ceiling_apex := actor.global_position.y
 for i in range(80):
  await frames(1)
  ceiling_apex = maxf(ceiling_apex,actor.global_position.y)
 check("jump ceiling collision",ceiling_apex<1.35,ceiling_apex)
 await place_actor(Vector3(-10,0.94,2))
 await frames(70,walk)
 check("step traversal climbs configured low steps",actor.global_position.z < -2.4 and actor.global_position.y>1.45,actor.global_position)
 await place_actor(Vector3(-16,0.94,9))
 await frames(65,walk)
 check("walkable slope gains height",actor.global_position.y>1.25,actor.global_position)
 await place_actor(Vector3(-21,0.94,9))
 await frames(120,walk)
 check("steep slope does not become walkable",actor.global_position.y<1.5,actor.global_position)
 arena.rig.foot_mode = 2 # Put the wall inside the selected far-mode sweep.
 await place_actor(Vector3(-8,0.94,10))
 await frames(20)
 check("camera obstruction sweep retracts",arena.rig.obstruction_fraction<0.85 and arena.rig.camera.global_position.z<13.65,arena.rig.obstruction_fraction)
 arena.rig.foot_mode = 1
 # Fixed seed and zero spread isolate cadence and damage from aiming variance.
 gun.profile = gun.profile.duplicate()
 gun.profile.spread_radians = 0
 gun.profile.recoil_radians = 0
 gun.magazine = 12
 gun.reserve = 240
 gun.cooldown = 0
 gun.reload_left = 0
 await place_actor(Vector3(-0.6,0.94,-3))
 arena.rig.pitch = 0
 var shoot := GameplayCommand.new()
 shoot.aim = true
 shoot.fire = true
 await frames(30,shoot)
 check("camera aim resolves hits",gun.last_hit,gun.last_hit)
 check("damage applied to target",arena.targets[1].health<100,arena.targets[1].health)
 var initial_shots := gun.shots
 var shot_ticks: Array[int] = []
 for i in range(60):
  var before := gun.shots
  await frames(1,shoot)
  if gun.shots>before: shot_ticks.append(arena.tick_number)
 var spacing_ok := shot_ticks.size()>=4
 for i in range(1,shot_ticks.size()):
  if shot_ticks[i]-shot_ticks[i-1] != 12: spacing_ok = false
 check("firing cadence every 12 ticks at 60 Hz",spacing_ok,shot_ticks)
 check("ammo decreases per shot",gun.magazine==12-gun.shots,gun.magazine)
 gun.magazine = 0
 gun.reload_left = 0
 var old_reserve := gun.reserve
 var reload_cmd := GameplayCommand.new()
 reload_cmd.reload = true
 await frames(1,reload_cmd)
 await frames(73)
 check("reload transfers reserve without duplication",gun.magazine==12 and gun.reserve==old_reserve-12,[gun.magazine,gun.reserve])
 # Vehicle suspension equilibrium and load conservation.
 car.reset_at(Vector3(18,1.8,25))
 await frames(240)
 var total_load := 0.0
 var contact_count := 0
 for wheel in car.wheels:
  total_load += wheel.normal_load
  if wheel.touching: contact_count += 1
 metrics.suspension = {"load_N":total_load,"height_m":car.global_position.y,"vertical_speed":car.linear_velocity.y}
 check("suspension supports four wheel contacts",contact_count==4,contact_count)
 check("suspension settles near static weight",absf(total_load-car.mass*float(ProjectSettings.get_setting("physics/3d/default_gravity")))<car.mass*float(ProjectSettings.get_setting("physics/3d/default_gravity"))*0.12,metrics.suspension)
 check("suspension vertical oscillation settles",absf(car.linear_velocity.y)<0.05,car.linear_velocity.y)
 await place_actor(car.global_position+Vector3(-1.7,0.22,0))
 var began: bool = seat.request_enter(car)
 check("valid approach reserves seat",began and car.reservation==actor and car.driver==null)
 var rival := Node.new()
 root.add_child(rival)
 check("duplicate occupancy rejected",not car.reserve_seat(rival))
 rival.queue_free()
 var enter_start: int = arena.tick_number
 await frames(40)
 check("entry commits control once",seat.state=="driving" and car.driver==actor and car.reservation==null and not actor.control_enabled,seat.state)
 check("entry duration bounded by one tick",absf(seat.last_duration-seat.profile.enter_seconds)<=1.0/60.0+0.00001,seat.last_duration)
 var drive := GameplayCommand.new()
 drive.move = Vector2(0,-1)
 var vehicle_start := car.global_position
 await frames(150,drive)
 metrics.acceleration = {"time_s":2.5,"speed_mps":car.speed,"distance_m":vehicle_start.distance_to(car.global_position)}
 check("vehicle accelerates forward",car.speed>8 and car.global_position.z<vehicle_start.z-8,metrics.acceleration)
 var steer := GameplayCommand.new()
 steer.move = Vector2(1,-1)
 var initial_forward := -car.global_basis.z
 await frames(45,steer)
 check("steering changes heading",initial_forward.angle_to(-car.global_basis.z)>0.15,initial_forward.angle_to(-car.global_basis.z))
 var braking := GameplayCommand.new()
 braking.brake = true
 var braking_start := car.global_position
 var initial_speed := absf(car.speed)
 var brake_ticks := 0
 for i in range(240):
  await frames(1,braking)
  brake_ticks += 1
  if car.linear_velocity.length()<0.25: break
 metrics.braking = {"initial_speed_mps":initial_speed,"distance_m":braking_start.distance_to(car.global_position),"time_s":brake_ticks/60.0}
 check("brakes bring vehicle to rest",car.linear_velocity.length()<0.35,metrics.braking)
 await frames(90,backward)
 check("reverse engages after stop",car.speed < -2,car.speed)
 await frames(180,braking)
 # Occupancy remains committed when every exit volume is blocked.
 var blockers: Array[Node] = []
 for offset in seat.profile.exit_offsets:
  var p: Vector3 = car.global_transform*offset
  p.y = 1.5
  blockers.append(LabGeometry.box(arena,Vector3(1.6,3,1.6),p,Color.RED,true))
 await frames(5,braking)
 check("blocked exits preserve ownership",not seat.request_exit() and car.driver==actor and not actor.control_enabled)
 for blocker in blockers: blocker.queue_free()
 await frames(5,braking)
 check("clear exit begins transition",seat.request_exit())
 await frames(35,braking)
 check("exit restores on foot ownership and collision",seat.state=="on_foot" and car.driver==null and actor.control_enabled and actor.collision_layer==2,seat.state)
 check("exit timing bounded by one tick",absf(seat.last_duration-seat.profile.exit_seconds)<=1.0/60.0+0.00001,seat.last_duration)
 var on_foot_start := actor.global_position
 await frames(40,walk)
 check("movement resumes without restarting",actor.global_position.distance_to(on_foot_start)>2.0)
 # Exercise repeat cycles in the same scene, no reload or state reset.
 var cycles := 0
 for cycle in range(3):
  await place_actor(car.global_position+Vector3(-1.7,0.22,0))
  if not seat.request_enter(car): break
  await TransitionTestWait.approach(arena)
  await frames(40)
  if not seat.request_exit(): break
  await frames(35)
  if seat.state=="on_foot" and car.driver==null: cycles += 1
 check("three additional enter exit cycles",cycles==3,cycles)
 # A blocker arriving during exit cancels the commit and keeps control unique.
 await place_actor(car.global_position+Vector3(-1.7,0.22,0))
 seat.request_enter(car)
 await TransitionTestWait.approach(arena)
 await frames(40)
 seat.request_exit()
 var late_blockers: Array[Node] = []
 for offset in seat.profile.exit_offsets:
  var p: Vector3 = car.global_transform*offset
  p.y = 1.5
  late_blockers.append(LabGeometry.box(arena,Vector3(1.6,3,1.6),p,Color.RED,true))
 await frames(40)
 check("late exit blockers cancel commit safely",seat.state=="driving" and car.driver==actor and not actor.control_enabled,seat.state)
 for blocker in late_blockers: blocker.queue_free()
 await frames(4)
 seat.request_exit()
 await frames(40)
 # Regression: wheel point velocity must be independent of world translation.
 await place_actor(car.global_position+Vector3(-1.7,0.22,0))
 seat.request_enter(car)
 await TransitionTestWait.approach(arena)
 await frames(40)
 var acceleration_samples: Array[float] = []
 for z in [35.0,-25.0]:
  car.reset_at(Vector3(18,0.9,z))
  await frames(120)
  await frames(60,drive)
  acceleration_samples.append(car.speed)
 check("vehicle dynamics invariant under world translation",absf(acceleration_samples[0]-acceleration_samples[1])<0.03,acceleration_samples)
 await frames(180,braking)
 seat.request_exit()
 await frames(40)
 check("vehicle remains stable after control restoration",car.linear_velocity.length()<0.2,car.linear_velocity.length())
 var shots_before_resume := gun.shots
 await frames(1,shoot)
 check("weapon control resumes after driving",gun.shots==shots_before_resume+1,{"phase":actor.phase,"grounded":actor.grounded,"control":actor.control_enabled,"life":actor.actions.life,"cooldown":gun.cooldown,"ammo":gun.magazine,"shots":gun.shots-shots_before_resume,"facing":actor.facing,"yaw":arena.rig.yaw})
 var impact_car: DriveVehicle = preload("res://scenes/vehicle.tscn").instantiate()
 arena.add_child(impact_car)
 impact_car.position = Vector3(18,0.9,35)
 var crash_wall := LabGeometry.box(arena,Vector3(8,4,0.5),Vector3(18,2,25),Color.GRAY,true)
 await frames(120)
 impact_car.command(drive)
 await frames(180)
 check("vehicle body collides without crossing wall",impact_car.global_position.z>26.8 and impact_car.global_position.z<30.0,impact_car.global_position)
 impact_car.queue_free()
 crash_wall.queue_free()
 await frames(2)
 metrics.vehicle_force_cpu = car.force_telemetry.summary()
 metrics.vehicle_force_cpu.scope = "four wheel queries and forces; excludes Jolt contact solve"
 metrics.gameplay_cpu = arena.telemetry.summary()
 metrics.physics_process_seconds_last = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
 metrics.node_count = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 var report := {"engine":Engine.get_version_info(),"backend":"Jolt Physics","fixed_hz":60,"failures":failures,"assertions":results.size(),"results":results,"metrics":metrics,"reference_runtime_tested":false,"parity_claim":"none; prototype acceptance only"}
 var output := FileAccess.open("res://tests/latest_results.json",FileAccess.WRITE)
 output.store_string(JSON.stringify(report,"  "))
 output.close()
 print("RESULT ",results.size()," assertions / ",failures," failures")
 arena.queue_free()
 await process_frame
 quit(1 if failures>0 else 0)
