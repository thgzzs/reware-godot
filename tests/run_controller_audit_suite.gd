extends SceneTree
## Public synthetic clips plus the production Jolt motor; no proprietary test input.
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
func reset()->void:
 arena.actor.respawn(Vector3(-28,0.94,38));arena.actor.facing=0;arena.rig.yaw=0
 await frames(20)
func run()->void:
 var input:=LocalInputSource.new();input.install()
 var before:=InputMap.action_get_events("jump").size();input.install()
 check("install retains bindings without duplicates",InputMap.action_get_events("jump").size()==before)
 for action in ["left","forward","jump","interact","aim","fire","look_left","look_down"]:
  var present:=false
  for event in InputMap.action_get_events(action):present=present or event is InputEventJoypadMotion or event is InputEventJoypadButton
  check("gamepad uses the shared action "+action,present)
 var stick:=InputEventJoypadMotion.new();stick.axis=JOY_AXIS_LEFT_X;stick.axis_value=0.65
 Input.parse_input_event(stick);Input.flush_buffered_events()
 var sampled:=input.sample()
 check("joypad axis reaches GameplayCommand with analog strength",sampled.move.x>0.3 and sampled.move.x<0.9,sampled.move)
 stick.axis_value=0;Input.parse_input_event(stick);Input.flush_buffered_events()
 check("joypad axis release clears movement",input.sample().move==Vector2.ZERO)
 # Inject stick rate, independent from mouse/touch accumulated deltas.
 var look:=GameplayCommand.new();look.look_stick=Vector2(0.6,0)
 var yaws:Array[float]=[]
 for hz in [30,60,120]:
  var rig:=FollowCameraRig.new();rig.profile=CameraProfile.new()
  for i in range(hz):rig.read_look(look,1.0/hz)
  yaws.append(rig.yaw);rig.free()
 check("stick yaw is invariant at 30/60/120 Hz",absf(yaws[0]-yaws[2])<0.00001 and absf(yaws[1]-yaws[2])<0.00001,yaws)
 var motion:=ReferenceMotion.new(TraversalTestFixture.library())
 var loop:=motion.loop_segment("run_player",0.1,1.85)
 check("root integration handles more than three loops",loop.distance_to(Vector3(0,0,-7))<0.00001,loop)
 var split:=motion.loop_segment("run_player",0.1,0.6)+motion.loop_segment("run_player",0.6,1.85)
 check("loop displacement is additive across a delayed tick",loop.distance_to(split)<0.00001)
 check("zero-time motion is zero",motion.loop_segment("run_player",0.2,0.2)==Vector3.ZERO)
 arena=load("res://scenes/arena.tscn").instantiate();arena.test_mode=true;arena.enable_reference_assets=false;root.add_child(arena)
 await frames(60)
 var actor:CharacterMotor=arena.actor
 actor.configure_reference(ImportedGameplayDatabase.new(),"STAT_PLAYER",TraversalTestFixture.library())
 var speeds:Array[float]=[]
 for magnitude in [0.5,1.0]:
  await reset()
  var aim:=GameplayCommand.new();aim.move=Vector2(0,-magnitude);aim.aim=true
  await frames(100,aim);speeds.append(Vector2(actor.drive_velocity.x,actor.drive_velocity.z).length())
 # The fixture blends walk=1.5 and run=4.0 m/s. A half stick selects walk;
 # it must not multiply that already-selected root speed by another 0.5.
 check("half-stick aiming consumes its full selected walk root",absf(speeds[0]-1.5*actor.actions.profile.aim_movement_multiplier)<0.02,speeds)
 check("full-stick aiming consumes selected run root",absf(speeds[1]-4.0*actor.actions.profile.aim_movement_multiplier)<0.02,speeds)
 var second:=actor.weapon.profile.duplicate();second.id="audit_second"
 actor.weapon.configure_loadout([actor.weapon.profile,second]);actor.actions.firing_left=0.2;actor.actions.reloading=true;actor.actions.reload_weight=1
 actor.weapon.equip_slot(1)
 check("switching cancels the preceding weapon action pose",actor.actions.firing_left==0 and not actor.actions.reloading and actor.actions.reload_weight==0)
 actor.profile=load("res://tuning/movement_classic.tres").duplicate()
 actor.configure_reference(ImportedGameplayDatabase.new(),"STAT_PLAYER",TraversalTestFixture.library())
 check("classic configuration survives reference setup",actor.profile.classic_revc and actor.profile.jump_buffer==0 and actor.profile.coyote_time==0 and actor.profile.air_acceleration==0)
 check("source gravity and player impulse use 50 Hz units",is_equal_approx(actor.profile.gravity,20) and absf(actor.profile.jump_speed-8.5*50/70.0)<0.00001)
 motion=actor.reference_motion;motion.phase="move";motion.intensity=0
 motion.step(1,false,false,0.1)
 check("classic intensity rises by 0.07 times normalized time",absf(motion.intensity-0.35)<0.00001,motion.intensity)
 motion.step(0,false,false,1.0/60)
 check("classic release clears movement intensity immediately",motion.intensity==0 and motion.phase=="idle")
 await reset()
 actor.weapon.profile=actor.weapon.profile.duplicate();actor.weapon.profile.source_flags=0x200
 var jump:=GameplayCommand.new();jump.jump=true
 var count:=actor.jump_count
 await frames(1,jump);await frames(50)
 check("classic heavy-weapon flag blocks jumping",actor.jump_count==count and actor.grounded)
 var sprint:=GameplayCommand.new();sprint.move=Vector2(0,-1);sprint.sprint=true
 await frames(80,sprint)
 check("classic heavy-weapon flag blocks sprinting",not actor.sprint.active)
 actor.weapon.profile.source_flags=0;actor.weapon.profile.heavy=true
 await frames(40,sprint)
 check("classic reads source bits instead of modern weapon-name tuning",actor.sprint.active)
 check("classic does not apply tap speed boosts",actor.sprint.multiplier==1)
 await reset()
 var run_cmd:=GameplayCommand.new();run_cmd.move=Vector2(0,-1)
 await frames(70,run_cmd);run_cmd.jump=true;await frames(1,run_cmd);run_cmd.jump=false
 for i in range(40):
  await frames(1,run_cmd)
  if actor.phase=="airborne":break
 var launch:=actor.drive_velocity
 var opposite:=GameplayCommand.new();opposite.move=Vector2(0,1)
 await frames(5,opposite)
 check("classic opposite air input retains planar launch momentum",actor.drive_velocity.distance_to(launch)<0.001 and not actor.grounded,{"before":launch,"after":actor.drive_velocity})
 await reset()
 actor.grounded=false;actor.phase="airborne";actor.global_position=Vector3(-28,5,38);actor.force_update_transform()
 await frames(1,jump)
 check("classic airborne edge does not create a buffered jump",actor.jump_left==0 and actor.phase!="launch")
 var report:={"engine":Engine.get_version_info().string,"assertions":results.size(),"failures":failures,"results":results,"assets":"synthetic clips, production Jolt collision","android_device_tested":false}
 var f:=FileAccess.open("res://tests/controller_audit_results.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("RESULT controller audit ",results.size()," / failures ",failures)
 arena.queue_free();await process_frame;quit(1 if failures else 0)
