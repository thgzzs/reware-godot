extends SceneTree
## Actual imported rig/weapon test: relaxed carrying is independent of aiming.
var arena:Node3D
var results:Array[Dictionary]=[]
var failures:=0
func _initialize() -> void:run.call_deferred()
func frames(n:int,cmd:GameplayCommand=null) -> void:
 arena.injected_command=cmd if cmd!=null else GameplayCommand.new()
 for i in range(n):await physics_frame;await process_frame
func check(label:String,ok:bool,value:Variant=null) -> void:
 results.append({"name":label,"passed":ok,"measured":value})
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label," ",value)
func slot(id:String) -> int:
 for i in range(arena.weapon.inventory.size()):
  if arena.weapon.inventory[i].profile.id==id:return i
 return -1
func run() -> void:
 arena=load("res://scenes/arena.tscn").instantiate();arena.test_mode=true;root.add_child(arena)
 await frames(90)
 for brain in arena.ped_brains:brain.set_physics_process(false)
 var actor:CharacterMotor=arena.actor
 var gun:WeaponController=actor.weapon
 var visual:SkinnedMotionVisual=actor.reference_pose
 var skeleton:=visual.skeleton
 var motion:=actor.reference_motion
 var shoulder:=skeleton.find_bone("R UpperArm")
 var left:=skeleton.find_bone("L Hand")
 var right:=skeleton.find_bone("R Hand")
 var thigh:=skeleton.find_bone("R Thigh")
 for id in ["shotgun","stubbyshotgun","spas12shotgun","ruger","m4"]:
  actor.respawn(Vector3(-35,0.94,44));gun.equip_slot(slot(id));await frames(40)
  var start:=actor.global_position;var shots:=gun.shots
  var state:=actor.actions
  var carry_clip:=state.resolve(PackedStringArray([gun.profile.animation_group+"_fire"]))
  check(id+" uses the native supported two-hand ready pose",state.standing_hold_clip==carry_clip and state.standing_hold_native_ready and state.standing_hold_weight>0.999,state.standing_hold_clip)
  check(id+" carrying never enables aim IK or firing",state.aim_weight==0 and gun.shots==shots)
  var error:=skeleton.get_bone_pose_rotation(shoulder).angle_to(visual.rotation_at(state.standing_hold_clip,state.standing_hold_time,shoulder))
  check(id+" standing shoulder follows its authored carry pose",error<0.002,error)
  var grip:=skeleton.get_bone_global_pose(right).affine_inverse()*skeleton.get_bone_global_pose(left)
  motion.preview_clip=state.standing_hold_clip;motion.preview_time=state.standing_hold_time;motion.preview_playing=false;visual.sample_pose(0.2)
  var native_grip:=skeleton.get_bone_global_pose(right).affine_inverse()*skeleton.get_bone_global_pose(left)
  motion.preview_clip="";visual.sample_pose(0.2)
  check(id+" preserves both hands' native grip relationship",grip.origin.distance_to(native_grip.origin)<0.003 and grip.basis.get_rotation_quaternion().angle_to(native_grip.basis.get_rotation_quaternion())<0.003,grip.origin.distance_to(native_grip.origin))
  check(id+" leaves the standing legs in the base idle",skeleton.get_bone_pose_rotation(thigh).angle_to(visual.base_rotations[thigh])<0.002)
  await frames(45)
  check(id+" idle loop neither drifts nor fires",actor.global_position.distance_to(start)<0.02 and gun.shots==shots)
  for walk in [true,false]:
   var moving:=GameplayCommand.new();moving.move=Vector2(0,-1);moving.walk=walk
   await frames(45,moving)
   check(id+(" walk" if walk else " run")+" keeps both hands in the authored grip",state.standing_hold_weight>0.999 and state.standing_hold_native_ready and state.aim_weight==0 and actor.drive_velocity.length()>0.5)
  await frames(50)
  var cmd:=GameplayCommand.new();cmd.aim=true
  var before:=skeleton.get_bone_pose_rotation(shoulder)
  await frames(1,cmd)
  check(id+" blends from carry into aim",state.aim_weight>0 and state.aim_weight<1 and before.angle_to(skeleton.get_bone_pose_rotation(shoulder))<0.75)
  await frames(24,cmd)
  check(id+" aim overrides the relaxed hold",state.aim_weight>0.999 and state.native_aim_hold)
  var max_step:=0.0
  for i in range(24):
   before=skeleton.get_bone_pose_rotation(shoulder);await frames(1)
   max_step=maxf(max_step,before.angle_to(skeleton.get_bone_pose_rotation(shoulder)))
  check(id+" lowers smoothly back into carry",state.aim_weight==0 and state.standing_hold_weight>0.999 and max_step<0.75,max_step)
  gun.magazine=maxi(0,gun.profile.magazine_size-1);gun.start_reload();await frames(15)
  check(id+" reload overrides carrying",state.reloading and state.reload_weight>0.99 and not state.native_aim_hold)
  gun.reload_left=0;await frames(25)
  cmd=GameplayCommand.new();cmd.move=Vector2(0,-1);cmd.sprint=true;await frames(60,cmd)
  check(id+" sprint releases the carry layer",state.standing_hold_weight==0 and not state.upper_allowed and actor.drive_velocity.length()>3)
 actor.respawn(Vector3(-35,0.94,44));gun.equip_slot(slot("colt45"));await frames(30)
 check("pistol standing pose is unaffected",actor.actions.standing_hold_clip.is_empty() and actor.actions.standing_hold_weight==0)
 gun.equip_slot(slot("m4"));await frames(30)
 actor.receive_damage(100000,actor.global_position,Vector3.FORWARD);await frames(3)
 check("death clears standing weapon ownership",actor.actions.standing_hold_weight==0 and actor.actions.life in ["dying","dead"])
 var report:={"engine":Engine.get_version_info().string,"assertions":results.size(),"failures":failures,"results":results,"android_device_tested":false}
 var file:=FileAccess.open("res://tests/standing_weapon_results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("RESULT standing weapons ",results.size()," / failures ",failures)
 arena.queue_free();await process_frame;quit(1 if failures else 0)
