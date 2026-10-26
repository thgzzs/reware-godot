extends SceneTree
## Native animation + Jolt regressions for input-gated landing and terrain death.
var arena:Node3D
var results:Array[Dictionary]=[]
var failures:=0
func _initialize()->void:run.call_deferred()
func frames(n:int,cmd:GameplayCommand=null)->void:
 arena.injected_command=cmd if cmd!=null else GameplayCommand.new()
 for i in range(n):await physics_frame;await process_frame
func check(label:String,ok:bool,value:Variant=null)->void:
 results.append({"name":label,"passed":ok,"measured":value})
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label," ",value)
func reset(height:=0.94)->void:
 arena.transition.abort_for_respawn();arena.actor.facing=0;arena.rig.yaw=0
 arena.actor.respawn(Vector3(-28,height,38))
func forward()->GameplayCommand:
 var cmd:=GameplayCommand.new();cmd.move=Vector2(0,-1);return cmd
func prepare_jump(running:bool)->int:
 reset();await frames(25)
 var cmd:=forward() if running else GameplayCommand.new()
 if running:await frames(40,cmd)
 var count:int=arena.actor.jump_count
 cmd.jump=true;await frames(1,cmd);cmd.jump=false
 for i in range(40):
  await frames(1,cmd)
  if not arena.actor.grounded and arena.actor.phase=="airborne":break
 return count
func landing_with_input(label:String,cmd:GameplayCommand)->void:
 var actor:CharacterMotor=arena.actor
 var landed:=false;var origin:=Vector3.ZERO;var travel:=0.0;var speed:=0.0
 var heading:=actor.facing;var turned:=0.0;var follow:=false
 for i in range(150):
  await frames(1,cmd)
  if not actor.grounded:turned=maxf(turned,absf(angle_difference(heading,actor.facing)))
  if actor.landing.active:
   if not landed:landed=true;origin=actor.global_position
   var d:=actor.global_position-origin;d.y=0;travel=maxf(travel,d.length())
   speed=maxf(speed,Vector2(actor.velocity.x,actor.velocity.z).length())
   follow=follow or not actor.landing.follow_clip.is_empty()
  if landed and not actor.landing.active:break
 check(label+" lands without an unrequested forward step",landed and travel<0.015 and speed<0.01 and not follow,{"travel":travel,"speed":speed,"follow":follow})
 check(label+" keeps the airborne heading stable",turned<0.001,turned)
func cancel_after_contact(opposite:bool)->void:
 await prepare_jump(true)
 var actor:CharacterMotor=arena.actor;var cmd:=forward();var reached:=false
 for i in range(120):
  await frames(1,cmd)
  if actor.landing.active:reached=true;break
 var at:=actor.global_position
 cmd=GameplayCommand.new()
 if opposite:cmd.move=Vector2(0,1)
 await frames(1,cmd)
 var delta:=actor.global_position-at;delta.y=0
 check(("opposite" if opposite else "released")+" input cancels landing root travel immediately",reached and delta.length()<0.005 and actor.drive_velocity.length()<0.01 and actor.landing.follow_clip.is_empty(),delta.length())
func run()->void:
 arena=load("res://scenes/arena.tscn").instantiate();arena.test_mode=true;root.add_child(arena);await frames(90)
 for brain in arena.ped_brains:brain.set_physics_process(false)
 var actor:CharacterMotor=arena.actor
 var count:=await prepare_jump(false)
 await landing_with_input("stationary jump",GameplayCommand.new())
 check("stationary jump completes once",actor.jump_count==count+1 and actor.phase=="grounded")
 await prepare_jump(true);await frames(6,forward())
 await landing_with_input("released running jump",GameplayCommand.new())
 await prepare_jump(true);await frames(6,forward())
 var opposite:=GameplayCommand.new();opposite.move=Vector2(0,1)
 var at:=actor.global_position;var facing:=actor.facing
 await frames(1,opposite)
 var delta:=actor.global_position-at;delta.y=0
 check("opposite air input hard-stops planar momentum without spinning",delta.length()<0.005 and actor.drive_velocity.length()<0.01 and absf(angle_difference(facing,actor.facing))<0.001,delta.length())
 await landing_with_input("opposite-input jump",opposite)
 await cancel_after_contact(false);await cancel_after_contact(true)
 reset();await frames(25);await frames(60,forward())
 at=actor.global_position;facing=actor.facing;await frames(1,opposite)
 delta=actor.global_position-at;delta.y=0
 check("opposite ground input stops immediately before the pivot",delta.length()<0.005 and actor.drive_velocity.length()<0.01 and absf(angle_difference(facing,actor.facing))<0.07,delta.length())
 reset();await frames(25)
 var sprint:=forward();sprint.sprint=true;await frames(75,sprint);await frames(1)
 var stopping:=actor.reference_motion.phase=="stop"
 at=actor.global_position;await frames(1,opposite);delta=actor.global_position-at;delta.y=0
 check("opposite input also interrupts a locked sprint-stop clip",stopping and delta.length()<0.005 and actor.drive_velocity.length()<0.01,delta.length())
 # A press just before support survives contact compression and launches once.
 count=await prepare_jump(false)
 var pressed:=false
 for i in range(160):
  var cmd:=GameplayCommand.new()
  if not pressed and not actor.grounded and actor.velocity.y< -3 and actor.global_position.y<1.35:cmd.jump=true;pressed=true
  await frames(1,cmd)
  if actor.jump_count>=count+2:break
 check("buffered jump survives the soft landing contact phase",pressed and actor.jump_count==count+2,{"pressed":pressed,"jumps":actor.jump_count-count})
 # Surviving high falls collapse directly, then get up once, never replay landing.
 reset(7.94);actor.drive_velocity=Vector3.FORWARD*4;actor.velocity=actor.drive_velocity
 var landing_events:=actor.landing.events;var falls:=actor.fall.landing_events
 var roll:=false;var down:=false;var got_up:=false;var resumed:=false;var replay:=false;var damage:=0.0
 for i in range(600):
  await frames(1)
  roll=roll or actor.reference_motion.clip=="FALL_fall"
  down=down or actor.actions.life=="down";got_up=got_up or actor.actions.life=="getting_up"
  damage=maxf(damage,actor.fall.last_damage)
  if got_up and actor.actions.life=="alive":resumed=true;break
 for i in range(60):
  await frames(1)
  replay=replay or actor.landing.active or actor.reference_motion.clip in ["FALL_land","JUMP_land"]
 check("high survivable fall collapses without rolling",down and got_up and resumed and not roll and damage>0 and actor.health.health>0,{"down":down,"getup":got_up,"resumed":resumed,"roll":roll,"damage":damage})
 check("get-up cannot replay the old landing",not replay and actor.landing.events==landing_events and actor.phase=="grounded" and actor.phase_left==0 and actor.control_enabled)
 check("survivable fall applies impact once",actor.fall.landing_events==falls+1)
 # A lethal impact must visibly progress to a grounded terminal corpse pose.
 reset(18.94);falls=actor.fall.landing_events;landing_events=actor.landing.events
 var visual:SkinnedMotionVisual=actor.reference_pose
 var initial:Array[Quaternion]=[];var pose_change:=0.0;var saw_dying:=false;var got_up_dead:=false;roll=false
 for i in range(600):
  await frames(1)
  roll=roll or actor.reference_motion.clip=="FALL_fall"
  got_up_dead=got_up_dead or actor.actions.life=="getting_up"
  if actor.actions.life=="dying":
   saw_dying=true
   if initial.is_empty():
    for bone in range(visual.skeleton.get_bone_count()):initial.append(visual.skeleton.get_bone_pose_rotation(bone))
   else:
    for bone in range(initial.size()):pose_change=maxf(pose_change,initial[bone].angle_to(visual.skeleton.get_bone_pose_rotation(bone)))
  if actor.corpse_retired:break
 var minimum:=visual.to_global(Vector3(0,visual.skin_minimum_y(),0)).y
 check("fatal fall animates the impact instead of freezing in glide",saw_dying and pose_change>0.2 and actor.actions.life=="dead" and actor.reference_motion.clip!="FALL_glide",{"change_radians":pose_change,"clip":actor.reference_motion.clip})
 check("fatal fall finishes as a grounded terminal corpse",actor.corpse_retired and minimum> -0.03 and minimum<0.08 and not roll and not got_up_dead and not actor.control_enabled,{"minimum_y":minimum,"retired":actor.corpse_retired,"roll":roll})
 check("fatal fall cancels every pending landing phase",not actor.landing.active and actor.landing.events==landing_events and actor.fall.landing_events==falls+1 and actor.phase_left==0 and actor.jump_left==0)
 var report:={"engine":Engine.get_version_info().string,"assertions":results.size(),"failures":failures,"results":results,"android_device_tested":false}
 var file:=FileAccess.open("res://tests/landing_control_results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("RESULT landing control ",results.size()," / failures ",failures)
 arena.queue_free();await process_frame;quit(1 if failures else 0)
