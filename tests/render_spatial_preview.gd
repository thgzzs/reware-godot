extends SceneTree
var arena:Node3D
func _initialize() -> void:run.call_deferred()
func frames(n:int,cmd:GameplayCommand=null) -> void:
 arena.injected_command=cmd if cmd!=null else GameplayCommand.new()
 for i in range(n):await physics_frame;await process_frame
func capture(name:String,offset:=Vector3(-3,1.1,2.7),target:Node3D=null) -> void:
 var subject:Node3D=arena.actor if target==null else target
 arena.set_physics_process(false);arena.rig.camera.global_position=subject.global_position+offset;arena.rig.camera.look_at(subject.global_position+Vector3.UP*0.1)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/spatial-"+name+".png");print("CAPTURE ",name)
 arena.set_physics_process(true)
func run() -> void:
 arena=load("res://scenes/arena.tscn").instantiate();arena.test_mode=true;root.add_child(arena);await frames(100)
 for brain in arena.ped_brains:brain.set_physics_process(false)
 var actor:CharacterMotor=arena.actor
 actor.respawn(Vector3(-25,0.94,38));actor.facing=0;actor.visual.rotation.y=0;arena.rig.yaw=0
 var cmd:=GameplayCommand.new();cmd.move=Vector2(0,-1);cmd.walk=true;await frames(100,cmd);await capture("walking")
 cmd.walk=false;await frames(60,cmd);cmd.move=Vector2(1,0);await frames(18,cmd);await capture("turning")
 actor.respawn(Vector3(-25,0.94,38));actor.facing=0;actor.visual.rotation.y=0;await frames(30)
 cmd.move=Vector2(0,-1);await frames(60,cmd);cmd.jump=true;await frames(1,cmd);cmd.jump=false
 for i in range(80):
  await frames(1,cmd)
  if actor.phase=="airborne":break
 await frames(8,cmd);await capture("airborne")
 for i in range(100):
  await frames(1,cmd)
  if actor.landing.active and actor.landing.time>0.05:break
 await capture("landing")
 var bike:DriveVehicle=arena.get_node("pcj600")
 await capture("parked-upright",Vector3(-3,1.3,3),bike)
 bike.reset_at(Vector3(-12,0.8,30));bike.reset_transform.basis=Basis(Vector3.FORWARD,1.2);bike.bike.standing=false;await frames(160)
 await capture("fallen-side",Vector3(-3,1.3,3),bike)
 actor.respawn(bike.approach_position(0,0));await frames(40);arena.transition.request_enter(bike)
 for i in range(650):
  await frames(1)
  if arena.transition.state=="lifting" and arena.transition.lift_elapsed>0.75:break
 await capture("pickup",Vector3(-3,1.3,3),bike)
 for i in range(650):
  await frames(1)
  if arena.transition.state in ["driving","on_foot"]:break
 if arena.transition.state!="driving":push_error("Pickup render did not complete: "+arena.transition.message);quit(1);return
 var wall:=LabGeometry.box(arena,Vector3(6,3,0.4),bike.global_position+Vector3(0,1,-4),Color.GRAY,true);await frames(2)
 bike.linear_velocity=Vector3(0,0,-14);bike.brake=0
 for i in range(90):
  await frames(1)
  if arena.transition.state=="on_foot" and actor.reaction_body.active:break
 await frames(5);await capture("bike-fall-pose")
 await frames(10);await capture("bike-fall-followthrough")
 arena.queue_free();await process_frame;quit()
