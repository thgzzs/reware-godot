extends SceneTree
## Synthetic animations test contracts without redistributing game assets.
var arena: Node3D
var results: Array[Dictionary] = []
var failures := 0
func _initialize() -> void: run.call_deferred()
func frames(count: int, command: GameplayCommand = null) -> void:
	arena.injected_command = command if command!=null else GameplayCommand.new()
	for i in range(count):
		await physics_frame
		await process_frame
func check(name: String, condition: bool, measured: Variant = null) -> void:
	results.append({"name":name,"passed":condition,"measured":measured})
	if not condition: failures += 1
	print("PASS " if condition else "FAIL ",name," ",measured)
func library() -> AnimationLibrary:
	var result := AnimationLibrary.new()
	for name in ["IDLE_stance","WALK_start","WALK_player","run_player","sprint_civi","Run_stop","Run_stopR","JUMP_launch","JUMP_land","JUMP_glide","CAR_sit","CAR_open_LHS","CAR_close_LHS","CAR_closedoor_LHS","CAR_getin_LHS","CAR_getout_LHS","KO_shot_front","KO_skid_front","GETUP_front","IDLE_armed","colt45_fire","colt45_reload"]:
		var animation := Animation.new()
		animation.length = 0.5
		var root_track := animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(root_track,NodePath("Skeleton3D:Root"))
		animation.position_track_insert_key(root_track,0,Vector3.ZERO)
		animation.position_track_insert_key(root_track,0.5,Vector3(0,0,-1.8 if name=="sprint_civi" else -1.0))
		for bone in ["R Thigh","R UpperArm"]:
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track,NodePath("Skeleton3D:"+bone))
			var angle := 0.8 if name=="run_player" else 0.2
			if name=="IDLE_armed" or name=="colt45_fire": angle = -1.0
			if name=="KO_shot_front": angle = 1.4
			animation.rotation_track_insert_key(track,0,Quaternion(Vector3.RIGHT,angle))
			animation.rotation_track_insert_key(track,0.5,Quaternion(Vector3.RIGHT,angle))
		result.add_animation(name,animation)
	return result
func visual(actor: CharacterMotor) -> SkinnedMotionVisual:
	var driver := SkinnedMotionVisual.new()
	driver.motion = actor.reference_motion
	driver.actions = actor.actions
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	for row in [["Root","",Vector3.ZERO],["Pelvis","Root",Vector3.ZERO],["Spine1","Pelvis",Vector3(0,0.2,0)],["R Thigh","Pelvis",Vector3(0.12,-0.1,0)],["R UpperArm","Spine1",Vector3(0.2,0.2,0)],["R Forearm","R UpperArm",Vector3(0.25,0,0)],["R Hand","R Forearm",Vector3(0.24,0,0)]]:
		var index := skeleton.add_bone(row[0])
		if row[1]!="": skeleton.set_bone_parent(index,skeleton.find_bone(row[1]))
		skeleton.set_bone_rest(index,Transform3D(Basis.IDENTITY,row[2]))
		skeleton.set_bone_pose_position(index,row[2])
	driver.add_child(skeleton)
	actor.visual.add_child(driver)
	driver.set_process(false)
	return driver
func run() -> void:
	arena = preload("res://scenes/arena.tscn").instantiate()
	arena.test_mode = true
	arena.enable_reference_assets = false
	root.add_child(arena)
	await frames(60)
	var actor: CharacterMotor = arena.actor
	var gun: WeaponController = arena.weapon
	var car: DriveVehicle = arena.vehicle
	check("all arena blocks retain plain colors by default",not arena.placeholder_assets.decorate_arena)
	check("nearest vehicle returns the actual registered body",arena.nearest_vehicle()==car)
	var event_count := InputMap.action_get_events("weapon_next").size()
	LocalInputSource.new().install()
	check("input installation is idempotent",InputMap.action_get_events("weapon_next").size()==event_count)
	gun.magazine = 7
	gun.reserve = 51
	gun.reload_left = 0.8
	gun.cooldown = 0.18
	check("switch to rifle succeeds",gun.equip_slot(1) and gun.profile.heavy)
	check("weapon switch cancels reload and preserves shot lock",gun.reload_left==0 and is_equal_approx(gun.cooldown,0.18))
	gun.magazine = 21
	gun.equip_slot(0)
	check("weapon ammo belongs to its slot",gun.magazine==7 and gun.reserve==51)
	gun.equip_slot(1)
	check("second weapon retains its own magazine",gun.magazine==21)
	var record := {"name":"Colt45","firing_rate_ms":250.0,"animation_frames":[13.0,21.0],"reload_ms":450.0,"clip_size":17,"damage":25.0,"range":30.0,"animation_group":"colt45"}
	var mapped := ImportedAssetSetup.weapon_profile(record,gun.profile)
	check("cadence follows source 30 Hz animation conversion",is_equal_approx(mapped.interval,0.24),mapped.interval)
	actor.configure_reference(ImportedGameplayDatabase.new(),"STAT_PLAYER",library())
	var driver := visual(actor)
	var motion := actor.reference_motion
	motion.phase = "move"; motion.was_sprinting = false; motion.intensity = 1.5; motion.cycle = 0.25
	driver.sample_pose(0.2)
	var thigh := driver.skeleton.find_bone("R Thigh")
	var blended := driver.skeleton.get_bone_pose_rotation(thigh)
	check("walk and run blend at matching normalized phase",blended.angle_to(Quaternion(Vector3.RIGHT,0.5))<0.001)
	actor.actions.aim_weight = 1
	driver.sample_pose(0.2)
	check("aim preserves leg locomotion",driver.skeleton.get_bone_pose_rotation(thigh).angle_to(blended)<0.001)
	check("upper action actually moves the gun arm",driver.skeleton.get_bone_pose_rotation(driver.skeleton.find_bone("R UpperArm")).angle_to(Quaternion.IDENTITY)>0.2)
	actor.actions.aim_weight = 0
	motion.phase = "launch"; motion.set_clip("JUMP_launch")
	driver.sample_pose(1.0/60)
	check("action changes crossfade instead of snapping",driver.transition_time<actor.actions.profile.blend_seconds and driver.skeleton.get_bone_pose_rotation(thigh).angle_to(blended)>0.001 and driver.skeleton.get_bone_pose_rotation(thigh).angle_to(blended)<0.3)
	var move := GameplayCommand.new()
	move.move = Vector2(0,-1); move.sprint = true
	actor.reset_at(Vector3(-28,0.94,30))
	await frames(20)
	await frames(90,move)
	check("heavy gun permits source sprint clip",motion.clip=="sprint_civi" and actor.velocity.length()>3, [motion.clip,actor.velocity.length()])
	var aim := GameplayCommand.new()
	aim.move = Vector2(1,0); aim.aim = true
	await frames(40,aim)
	check("aiming and walking coexist",actor.drive_velocity.length()>0.1 and actor.actions.aim_weight>0.9)
	var firing := GameplayCommand.new(); firing.move = Vector2(0,-1); firing.aim = true; firing.fire = true
	var shots_before := gun.shots
	await frames(25,firing)
	driver.sample_pose(0.2)
	check("walking aiming and firing advance together",actor.drive_velocity.length()>0.1 and gun.shots>shots_before and actor.actions.firing_left>0)
	var reload_cmd := GameplayCommand.new(); reload_cmd.reload = true
	await frames(1,reload_cmd)
	await frames(20)
	driver.sample_pose(1.0/60)
	check("reload blends its own upper action while legs remain available",actor.actions.reloading and actor.actions.reload_weight>0.9)
	var all_sprint := true
	for slot in range(gun.inventory.size()):
		gun.equip_slot(slot)
		actor.reset_at(Vector3(-28,0.94,30))
		await frames(20)
		await frames(70,move)
		all_sprint = all_sprint and motion.clip=="sprint_civi" and actor.velocity.length()>3
	check("every equipped weapon supports sprint",all_sprint)
	actor.health.receive(1000)
	await frames(60)
	var death_time := actor.actions.life_time
	actor.health.receive(10)
	await frames(10)
	check("death plays once and holds its terminal frame",actor.actions.life=="dead" and is_equal_approx(motion.time,0.5) and actor.actions.life_time>death_time,[actor.actions.life,motion.time])
	check("death blocks movement and leaves a low world collision shape",not actor.control_enabled and actor.collision_layer==0 and actor.get_node("CollisionShape3D").shape is SphereShape3D)
	var respawn := GameplayCommand.new(); respawn.respawn = true
	await frames(1,respawn)
	await frames(10)
	check("respawn restores health and standing shape",actor.health.health==actor.health.max_health and actor.control_enabled and actor.get_node("CollisionShape3D").shape is CapsuleShape3D)
	car.damage.repair() # Independent fixture starts with an intact car.
	car.reset_at(Vector3(18,0.9,25))
	await frames(90)
	car.set_door_open(0,true)
	await frames(60)
	check("Jolt door hinge opens under motor force",absf(car.doors[0].angle)>0.5 and absf(car.doors[0].angle)<1.4,car.doors[0].angle)
	check("open hinge stays attached to chassis",car.doors[0].global_position.distance_to(car.global_transform*car.doors[0].hinge_offset)<0.06)
	car.set_door_open(0,false)
	await frames(150)
	check("door closes and latches without pinning chassis to world",car.doors[0].latched,car.doors[0].angle)
	var ped: CharacterMotor = preload("res://scenes/character.tscn").instantiate()
	arena.add_child(ped)
	ped.position = Vector3(18,0.94,20)
	for i in range(10):
		ped.tick(GameplayCommand.new(),0,1.0/60)
		await frames(1)
	car.linear_velocity = Vector3(0,0,-9)
	var impact_found := false
	for i in range(60):
		ped.tick(GameplayCommand.new(),0,1.0/60)
		await frames(1)
		if ped.actions.life!="alive": impact_found = true
	check("chassis sweep finds and reacts to pedestrian",impact_found and car.impact_probe.impacts>0,[car.impact_probe.impacts,ped.health.health,ped.actions.life])
	check("run-over reaction stays bounded",ped.reaction_velocity.length()<12 and ped.global_position.is_finite(),ped.reaction_velocity.length())
	var low: CharacterMotor = preload("res://scenes/character.tscn").instantiate()
	arena.add_child(low); low.position = Vector3(-28,0.94,35)
	low.receive_vehicle_impact(car,3.0,Vector3.FORWARD)
	check("low speed impact knocks down instead of instantly killing",low.health.health>0 and low.actions.life=="down")
	for i in range(240):
		low.tick(GameplayCommand.new(),0,1.0/60)
		await frames(1)
	check("nonfatal pedestrian gets up with standing volume clearance",low.actions.life=="alive" and low.control_enabled and low.get_node("CollisionShape3D").shape is CapsuleShape3D,[low.actions.life,low.global_position])
	low.reset_at(Vector3(-28,0.94,39))
	var ceiling := LabGeometry.box(arena,Vector3(4,0.6,4),Vector3(-28,1.5,39),Color.GRAY,true)
	await frames(1)
	low.receive_vehicle_impact(car,3.0,Vector3.FORWARD)
	for i in range(240):
		low.tick(GameplayCommand.new(),0,1.0/60)
		await frames(1)
	check("blocked standing volume prevents unsafe get-up",low.actions.life=="down" and not low.control_enabled)
	ceiling.queue_free()
	for i in range(100):
		low.tick(GameplayCommand.new(),0,1.0/60)
		await frames(1)
	check("get-up retries after overhead obstruction clears",low.actions.life=="alive")
	low.receive_vehicle_impact(car,24.0,Vector3.FORWARD)
	for i in range(60):
		low.tick(GameplayCommand.new(),0,1.0/60)
		await frames(1)
	var old_reaction := low.reaction_velocity
	low.receive_vehicle_impact(car,25.0,Vector3.RIGHT)
	check("fatal impact reaches death and repeated corpse hits do not restart it",low.actions.life=="dead" and low.health.health==0 and low.reaction_velocity==old_reaction)
	car.damage.repair() # Independent fixture starts with an intact car.
	car.reset_at(Vector3(18,0.9,25))
	await frames(90)
	car.set_door_open(1,true)
	await frames(60)
	check("right door opens in the opposite direction",car.doors[1].angle>0.5,car.doors[1].angle)
	car.set_door_open(1,false)
	await frames(150)
	check("right door also closes and latches",car.doors[1].latched)
	actor.respawn(car.approach_position())
	await frames(30)
	var seat: VehicleTransition = arena.transition
	seat.profile = seat.profile.duplicate()
	seat.profile.enter_open_seconds = 0.5; seat.profile.enter_close_seconds = 0.5; seat.profile.enter_seconds = 1.5
	seat.profile.exit_close_seconds = 0.5; seat.profile.exit_seconds = 1.0
	check("animated entry reserves a single owner",seat.request_enter(car) and car.reservation==actor)
	await TransitionTestWait.approach(arena)
	await frames(10)
	check("door action respects opening contact delay",motion.clip=="CAR_open_LHS" and not car.doors[0].opened)
	await frames(35)
	check("entry advances from opening to get-in",motion.clip=="CAR_getin_LHS" and car.doors[0].opened)
	await frames(27)
	check("inside close uses its own distinct source clip",motion.clip=="CAR_closedoor_LHS")
	await frames(25)
	check("animated stages commit after total clip duration",seat.state=="driving" and car.driver==actor and absf(seat.last_duration-1.5)<0.017)
	var started_exit := seat.request_exit()
	await frames(10)
	check("animated exit starts its get-out clip",started_exit and motion.clip=="CAR_getout_LHS")
	await frames(25)
	check("outside close uses the outside source clip",motion.clip=="CAR_close_LHS")
	await frames(30)
	check("animated exit restores control exactly once",seat.state=="on_foot" and actor.control_enabled and car.driver==null)
	actor.reset_at(car.approach_position())
	await frames(30)
	seat.request_enter(car)
	await frames(10)
	actor.health.receive(1000)
	await frames(2)
	check("death during entry releases reservation and controller",seat.state=="on_foot" and car.driver==null and car.reservation==null and not actor.control_enabled)
	var pose_samples := GameplayTelemetry.new()
	for i in range(180):
		driver.sample_pose(1.0/60)
		pose_samples.record(driver.sample_us)
	var pose_metrics := pose_samples.summary()
	pose_metrics.scope = "seven-bone synthetic skeleton; sample_pose CPU only; excludes rendering, real skin and Jolt"
	var report := {"engine":Engine.get_version_info().string,"backend":"Jolt Physics","assertions":results.size(),"failures":failures,"results":results,"asset_fixture":"synthetic; private original meshes/animations unavailable","reference_runtime_tested":false,"metrics":{"synthetic_pose_cpu":pose_metrics}}
	var output := FileAccess.open("res://tests/revision_results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"  ")); output.close()
	print("RESULT ",results.size()," assertions / ",failures," failures")
	arena.queue_free()
	await process_frame
	quit(1 if failures>0 else 0)
