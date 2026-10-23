extends SceneTree
var arena: Node3D
var results: Array[Dictionary] = []
var failures := 0
var metrics := {}
func _initialize() -> void: run.call_deferred()
func check(label: String, condition: bool, value: Variant = null) -> void:
 results.append({"name":label,"passed":condition,"measured":value})
 if not condition: failures += 1
 print("PASS " if condition else "FAIL ",label," ",value)
func frames(count: int, cmd: GameplayCommand = null) -> void:
 arena.injected_command = cmd if cmd!=null else GameplayCommand.new()
 for i in range(count):
  await physics_frame
  await process_frame
func place(where: Vector3) -> void:
 arena.actor.reset_at(where)
 arena.actor.facing = 0
 arena.actor.visual.rotation.y = 0
 arena.rig.yaw = 0
 await frames(20)
func validate_native() -> void:
 var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/converted/stories_animation_source.json"))
 var lib: AnimationLibrary = load(ImportedAssetSetup.LIBRARY_PATH)
 var bad := 0
 var keys := 0
 var channels := 0
 var max_position_error := 0.0
 var max_rotation_error := 0.0
 check("all ANPK clips present in native library",lib.get_animation_list().size()==source.clips.size()+source.aliases.size(),lib.get_animation_list().size())
 for clip in source.clips:
  if not lib.has_animation(clip.name):
   bad += 1
   continue
  var a := lib.get_animation(clip.name)
  if absf(a.length-clip.duration)>0.000001: bad += 1
  var cursor:=0
  for bone in clip.tracks:
   if bone.keys.is_empty(): continue
   var unique:Array[Dictionary]=[]
   for key in bone.keys:
    if not unique.is_empty() and float(unique[-1].time)==float(key.time):unique[-1]=key
    else:unique.append(key)
   bone=bone.duplicate()
   bone.keys=unique
   var path := NodePath("Skeleton3D:"+bone.bone)
   var mappings := [[Animation.TYPE_ROTATION_3D,"rotation"]]
   if bone.kind in ["KRT0","KRTS"]: mappings.append([Animation.TYPE_POSITION_3D,"position"])
   if bone.kind=="KRTS": mappings.append([Animation.TYPE_SCALE_3D,"scale"])
   for mapping in mappings:
    var tr := cursor
    cursor+=1
    channels += 1
    if tr<0 or a.track_get_key_count(tr)!=bone.keys.size():
     bad += 1
     continue
    for i in range(bone.keys.size()):
     keys += 1
     var expected: Array = bone.keys[i][mapping[1]]
     var value: Variant = a.track_get_key_value(tr,i)
     if absf(a.track_get_key_time(tr,i)-bone.keys[i].time)>0.000001: bad += 1
     if mapping[1]=="rotation":
      var q := Quaternion(expected[0],expected[1],expected[2],expected[3])
      var error := absf(1.0-absf(q.dot(value)))
      max_rotation_error = maxf(max_rotation_error,error)
      if error>0.000002: bad += 1
     else:
      var v := Vector3(expected[0],expected[1],expected[2])
      var error: float = v.distance_to(value)
      max_position_error = maxf(max_position_error,error)
      if error>0.000002: bad += 1
 metrics.native_roundtrip = {"channels":channels,"channel_keys":keys,"mismatches":bad,"max_position_or_scale_error":max_position_error,"max_quaternion_dot_error":max_rotation_error}
 check("every native key and timestamp matches decoded source",bad==0,metrics.native_roundtrip)
 var db: ImportedGameplayDatabase = load(ImportedAssetSetup.DATABASE_PATH)
 check("all source data tables loaded",db.ped_stats.size()==40 and db.weapons.size()==37 and db.handling.size()==106 and db.ped_groups.size()==67 and db.ped_types.size()==20)
 if not db.fight_moves.is_empty():
  var jab := db.find_record("fight_moves","Jab")
  check("fistfight rows and frame-to-second mapping preserved",db.fight_moves.size()==32 and absf(jab.start_seconds-jab.start_frame/30.0)<0.000001 and jab.damage_source==2,db.fight_moves.size())
  check("fistfight clips resolve without inventing sentinel animations",db.fight_moves.all(func(m: Dictionary): return m.animation_resolution!="missing" and (m.animation_resolution=="source_sentinel" or lib.has_animation(m.animation_clip))))
 check("sprint motion integrates across loop without reset spike",absf(ReferenceMotion.new(lib).loop_segment("sprint_civi",0.49,0.51).z)<0.5)
func run() -> void:
 if not ImportedAssetSetup.available():
  push_error("Import supplied assets before running this suite")
  quit(2)
  return
 validate_native()
 arena = preload("res://scenes/arena.tscn").instantiate()
 arena.test_mode = true
 root.add_child(arena)
 await frames(120)
 var actor: CharacterMotor = arena.actor
 var car: DriveVehicle = arena.vehicle
 var seat: VehicleTransition = arena.transition
 check("reference assets activated",actor.reference_enabled and actor.reference_motion!=null)
 if not arena.reference_database.fight_moves.is_empty():
  var browser: ImportedAnimationBrowser = arena.animation_browser
  browser.refilter("FIGHTjab")
  browser.select(0)
  check("fight configuration visible in clip inspector",browser.fight_note.contains("Jab: %.3f"%arena.reference_database.find_record("fight_moves","Jab").start_seconds) and browser.fight_note.contains("source damage 2"),browser.fight_note)
  actor.reference_motion.preview_clip = ""
 check("player and four pedestrians use identical motor script",arena.pedestrians.size()==4 and arena.pedestrians.all(func(p: CharacterMotor): return p.get_script()==actor.get_script() and p.reference_enabled))
 check("health and weapon components shared by actor types",arena.pedestrians.all(func(p: CharacterMotor): return p.health is PedHealth and p.weapon is WeaponController))
 check("player heading source unit converted explicitly",absf(actor.profile.turn_rate-deg_to_rad(15*50))<0.00001,actor.profile.turn_rate)
 var source_weapon: Dictionary = arena.reference_database.find_record("weapons","Colt45")
 var expected_interval := (float(source_weapon.animation_frames[1])-float(source_weapon.animation_frames[0]))*0.03
 check("weapon DAT fields and derived animation cadence applied",arena.weapon.magazine==17 and absf(arena.weapon.profile.interval-expected_interval)<0.00001 and arena.weapon.profile.reload_seconds>=source_weapon.reload_ms/1000.0,arena.weapon.profile.display_name)
 check("dimensionally mapped vehicle fields applied",car.mass==1600 and absf(car.profile.max_speed-160.0/3.6)<0.001 and absf(car.profile.steering_angle-deg_to_rad(30))<0.001)
 await place(Vector3(-30,0.94,40))
 var walking := GameplayCommand.new()
 walking.move = Vector2(0,-1)
 walking.walk = true
 var start := actor.global_position
 await frames(10,walking)
 check("walk start uses source clip",actor.reference_motion.clip=="WALK_start",actor.reference_motion.clip)
 await frames(80,walking)
 var walk_distance := start.distance_to(actor.global_position)
 var expected_walk:=actor.reference_motion.segment("WALK_start",0,actor.reference_motion.duration("WALK_start")).length()+(90.0/60.0-actor.reference_motion.duration("WALK_start"))*actor.reference_motion.segment("WALK_player",0,actor.reference_motion.duration("WALK_player")).length()/actor.reference_motion.duration("WALK_player")
 check("walk movement follows provided VCS stride",absf(walk_distance-expected_walk)<0.08,{"actual":walk_distance,"source":expected_walk})
 check("walk loop selected",actor.reference_motion.clip=="WALK_player",actor.reference_motion.clip)
 var turn_rate := actor.profile.turn_rate
 actor.profile.turn_rate = 0.5
 var right := GameplayCommand.new()
 right.move = Vector2(1,0)
 right.walk = true
 await frames(1,right)
 check("travel follows body heading while turning",absf(actor.drive_velocity.x)<absf(actor.drive_velocity.z),actor.drive_velocity)
 actor.profile.turn_rate = turn_rate
 await place(Vector3(-30,0.94,40))
 var sprint := GameplayCommand.new()
 sprint.move = Vector2(0,-1)
 sprint.sprint = true
 await frames(60,sprint)
 check("sprint source clip active",actor.reference_motion.clip=="sprint_civi",actor.reference_motion.clip)
 var stop_start := actor.global_position
 await frames(1)
 check("sprint release enters committed stop",actor.reference_motion.phase=="stop" and actor.reference_motion.heading_locked,actor.reference_motion.clip)
 var stopped_facing := actor.facing
 await frames(15,right)
 check("stop animation locks heading",absf(actor.facing-stopped_facing)<0.000001)
 check("stop root motion still moves the colliding body",actor.global_position.distance_to(stop_start)>0.1,actor.global_position.distance_to(stop_start))
 await frames(ceili(actor.reference_motion.duration(actor.reference_motion.clip)*60)+2)
 check("stop commitment completes",actor.reference_motion.phase!="stop")
 await place(Vector3(-30,0.94,40))
 var launch := GameplayCommand.new()
 launch.jump = true
 var previous := actor.jump_count
 await frames(1,launch)
 check("jump starts source launch clip",actor.reference_motion.clip=="JUMP_launch",actor.reference_motion.clip)
 await frames(5)
 check("jump waits for clip duration",actor.jump_count==previous)
 await frames(7)
 check("jump launches after imported timing gate",actor.jump_count==previous+1)
 await frames(80)
 check("jump and landing recover",actor.grounded and actor.phase=="grounded",actor.phase)
 # Every converted clip can be sampled on the active character skeleton.
 var finite_poses := true
 for name in actor.reference_motion.library.get_animation_list():
  actor.reference_motion.preview_clip = name
  actor.reference_motion.preview_time = actor.reference_motion.duration(name)*0.5
  actor.reference_motion.preview_playing = false
  await frames(1)
  for i in range(actor.reference_pose.skeleton.get_bone_count()):
   if not actor.reference_pose.skeleton.get_bone_global_pose(i).origin.is_finite(): finite_poses = false
 check("all 1168 entries sampled on active character skeleton without nonfinite poses",finite_poses)
 actor.reference_motion.preview_clip = ""
 actor.reference_motion.phase = "idle"
 check("browser exposes all imported clip names",arena.animation_browser.names.size()==actor.reference_motion.library.get_animation_list().size())
 car.damage.repair();car.reset_at(Vector3(24,0.9,20));await frames(80)
 await place(car.global_position+Vector3(-1.7,0.25,0))
 check("entry request accepted in imported mode",seat.request_enter(car))
 await frames(ceili(seat.profile.enter_seconds*60)+2)
 check("entry commits after open get-in and close clips",seat.state=="driving" and absf(seat.last_duration-seat.profile.enter_seconds)<1.0/60.0+0.00001,[seat.state,seat.last_duration])
 var drive := GameplayCommand.new()
 drive.move = Vector2(0,-1)
 await frames(90,drive)
 check("driving still accelerates with mapped data",car.speed>3,car.speed)
 var brake := GameplayCommand.new()
 brake.brake = true
 await frames(180,brake)
 check("exit request accepted",seat.request_exit())
 await frames(ceili(seat.profile.exit_seconds*60)+2)
 check("exit returns to shared on-foot actor",seat.state=="on_foot" and actor.control_enabled and actor.reference_enabled,seat.state)
 var before_shots: int = arena.weapon.shots
 var shoot := GameplayCommand.new()
 shoot.fire = true
 shoot.aim = true
 await frames(1,shoot)
 check("weapon works after imported enter drive exit loop",arena.weapon.shots==before_shots+1)
 await place(Vector3(-18,0.94,25))
 await frames(1,shoot)
 arena.weapon.shot_fired.emit(actor.global_position,actor.global_position-Vector3.FORWARD,true)
 await frames(1)
 var fleeing := 0
 for brain in arena.ped_brains:
  if brain.state=="flee": fleeing += 1
 check("NPC gun reaction consumes ped DAT relationships",fleeing>0,fleeing)
 var before_health := actor.health.health
 actor.receive_damage(25,actor.global_position,Vector3.ZERO)
 check("source player damage scales by 0.33 rather than NPC weakness",absf(before_health-actor.health.health-25.0*0.33)<0.001)
 metrics.gameplay_cpu = arena.telemetry.summary()
 metrics.model_binding_verified = "covered separately by presentation/stories rig-ID suites"
 var report := {"engine":Engine.get_version_info().string,"backend":"Jolt Physics","assertions":results.size(),"failures":failures,"results":results,"metrics":metrics,"claim":"native conversion and functional integration; rig bindings covered by separate native suites; reference-runtime parity unverified"}
 var file := FileAccess.open("res://tests/imported_results.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 file.close()
 print("RESULT imported ",results.size()," assertions / ",failures," failures")
 arena.queue_free()
 await process_frame
 quit(1 if failures>0 else 0)

