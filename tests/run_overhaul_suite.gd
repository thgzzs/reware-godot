extends SceneTree
var arena:Node3D
var results:Array[Dictionary]=[]
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(label:String,ok:bool,value:Variant=null) -> void:
 results.append({"name":label,"passed":ok,"measured":value})
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label," ",value)
func frames(n:int,cmd:GameplayCommand=null) -> void:
 arena.injected_command=cmd if cmd!=null else GameplayCommand.new()
 for i in range(n):await physics_frame;await process_frame
func reset(at:Vector3) -> void:
 arena.transition.abort_for_respawn()
 arena.actor.respawn(at)
 arena.rig.yaw=0;arena.rig.pitch=0
func slot(name:String) -> int:
 for i in range(arena.weapon.inventory.size()):
  if arena.weapon.inventory[i].profile.id==name:return i
 return -1
func pin(bike:DriveVehicle,at:Vector3) -> void:
 reset(at+Vector3.UP*0.94)
 var actor:CharacterMotor=arena.actor
 actor.health.health=1000
 actor.actions.begin_life("down");actor.control_enabled=false
 actor.actions.life_clip=actor.actions.resolve(PackedStringArray(["BIKE_fall_off","FALL_front"]))
 actor.reaction_body.launch_velocity(at+Vector3.UP*0.33,0,Vector3.ZERO)
 actor.reaction_body.recovery.impulses=0;actor.reaction_body.recovery.attempts=0
 bike.bike.standing=false
 bike.reset_at(at+Vector3.UP*0.78)
 bike.reset_transform.basis=Basis(Vector3.FORWARD,PI*0.5)
 bike.bike.standing=false;bike.control_owner="external"
func run() -> void:
 arena=load("res://scenes/arena.tscn").instantiate();arena.test_mode=true;root.add_child(arena)
 await frames(100)
 for brain in arena.ped_brains:brain.set_physics_process(false)
 var actor:CharacterMotor=arena.actor
 var bike:DriveVehicle=arena.get_node("pcj600")
 check("player and pedestrians own independent copies of the same recovery component",actor.reaction_body.recovery is PedRecoverySolver and arena.pedestrians[0].reaction_body.recovery is PedRecoverySolver and actor.reaction_body.recovery!=arena.pedestrians[0].reaction_body.recovery)
 var mark:=Vector3(-42,0,44)
 pin(bike,mark)
 var blocked:=false;var recovered:=false;var separation:=0.0
 for i in range(600):
  await frames(1)
  blocked=blocked or actor.reaction_body.recovery.blocked
  separation=maxf(separation,Vector2(actor.global_position.x-mark.x,actor.global_position.z-mark.z).length())
  if actor.actions.life=="alive" and actor.control_enabled:
   recovered=true;break
 check("actual Jolt bike-on-player contact is detected as a blocked stand-up",blocked)
 check("bike pin recovery applies physical separation impulses",actor.reaction_body.recovery.impulses>0,{"attempts":actor.reaction_body.recovery.attempts,"impulses":actor.reaction_body.recovery.impulses,"travel":separation})
 check("pinned player returns through get-up into live locomotion",recovered and actor.health.health>0,{"life":actor.actions.life,"at":actor.global_position,"bike":bike.global_position})
 check("recovery keeps bike collision active",bike.collision_layer!=0 and bike.collision_mask!=0)
 reset(Vector3(-35,0.94,44));bike.reset_at(Vector3(-35,0.9,32));await frames(90)
 var gun:WeaponController=arena.weapon
 var rifle:=slot("m4");var shotgun:=slot("shotgun")
 check("actual rifle and shotgun placeholder models are present",rifle>=0 and shotgun>=0)
 gun.equip_slot(rifle);await frames(2)
 var old_profile:=gun.profile;var commits:=[0]
 gun.equipped.connect(func(_p:WeaponProfile):commits[0]+=1)
 var cmd:=GameplayCommand.new();cmd.weapon_slot=shotgun
 await frames(1,cmd)
 check("weapon lowering preserves old attachment and ammo ownership",gun.profile==old_profile and gun.equip_action.phase=="lowering" and commits[0]==0)
 await frames(10)
 check("weapon switch commits once between lower and raise",gun.profile.id=="shotgun" and commits[0]==1,gun.equip_action.phase)
 await frames(12)
 check("weapon raise finishes without repeating the attachment commit",not gun.equip_action.busy() and commits[0]==1)
 gun.request_equip(rifle)
 actor.receive_damage(1000000,actor.global_position,Vector3.FORWARD)
 await frames(30)
 check("dying cancels pending equipment and upper-body ownership",not gun.equip_action.busy() and gun.profile.id=="shotgun" and actor.actions.aim_weight==0 and not actor.actions.melee_active)
 reset(Vector3(-35,0.94,44));await frames(15)
 gun.equip_slot(rifle);await frames(4)
 var pose:SkinnedMotionVisual=actor.reference_pose
 var shoulder:=pose.skeleton.find_bone("R UpperArm")
 var before:=pose.skeleton.get_bone_pose_rotation(shoulder)
 cmd=GameplayCommand.new();cmd.fire=true
 var shots:=gun.shots
 await frames(1,cmd)
 var angle:=before.angle_to(pose.skeleton.get_bone_pose_rotation(shoulder))
 check("hip fire starts raising the authored upper-body pose before firing presentation",actor.actions.aim_weight>0 and not pose.upper_signature.is_empty(),{"weight":actor.actions.aim_weight,"upper":pose.upper_signature,"angle":angle})
 check("hip-fire input retains immediate ballistic response",gun.shots>shots)
 check("first firing pose blends without a full-pose snap",is_finite(angle) and angle<1.4,angle)
 reset(Vector3(-44,0.94,32));await frames(15)
 gun.equip_action.reset()
 cmd=GameplayCommand.new();cmd.move=Vector2(0,-1)
 await frames(30,cmd)
 var origin:Vector3=actor.global_position
 var platform:=LabGeometry.box(arena,Vector3(2.4,0.5,2.4),origin+Vector3(0,-0.69,-2.4),Color.GRAY,true)
 await frames(2)
 var jump_count:=actor.jump_count
 cmd.jump=true;await frames(1,cmd);cmd.jump=false
 var elevated:=false;var saw_air:=false;var held_heading:=0.0;var heading_error:=0.0;var maximum_assist:=0.0
 for i in range(170):
  await frames(1,cmd)
  if not actor.grounded and actor.phase in ["airborne","falling"]:
   if not saw_air:held_heading=actor.facing;saw_air=true
   heading_error=maxf(heading_error,absf(angle_difference(actor.facing,held_heading)))
   maximum_assist=maxf(maximum_assist,actor.air_steering.length())
  elevated=elevated or (actor.grounded and actor.global_position.y>origin.y+0.3)
 check("jumping reaches an elevated collision platform",actor.jump_count>jump_count and saw_air and elevated,{"at":actor.global_position,"origin":origin,"landed_high":elevated})
 check("air steering preserves heading and remains bounded",heading_error<0.02 and maximum_assist<=actor.profile.air_control_speed+0.01,{"yaw_change":heading_error,"assist":maximum_assist})
 check("imported movement retains useful jump buffering and grace",actor.profile.jump_buffer>=0.1 and actor.profile.coyote_time>=0.06)
 platform.queue_free()
 check("bike reverse improves maneuvering while keeping model-specific caps",bike.bike.profile.reverse_speed>=2 and bike.bike.profile.reverse_speed<=3.25 and bike.bike.profile.reverse_acceleration>=1.8,{"speed":bike.bike.profile.reverse_speed,"acceleration":bike.bike.profile.reverse_acceleration})
 var report:={"engine":Engine.get_version_info().string,"assertions":results.size(),"failures":failures,"results":results,"android_device_tested":false}
 var f:=FileAccess.open("res://tests/overhaul_results.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("RESULT overhaul ",results.size()," / failures ",failures)
 arena.queue_free();await process_frame;quit(1 if failures else 0)
