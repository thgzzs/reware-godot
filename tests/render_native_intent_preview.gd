extends SceneTree
var arena:Node3D
func _initialize() -> void:run.call_deferred()
func frames(count:int,cmd:GameplayCommand=null) -> void:
 arena.injected_command=cmd if cmd!=null else GameplayCommand.new()
 for i in range(count):await physics_frame;await process_frame
func capture(label:String,eye:Vector3,target:Vector3) -> void:
 arena.set_physics_process(false)
 arena.rig.camera.global_position=eye;arena.rig.camera.look_at(target)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/intent-"+label+".png")
 print("CAPTURE ",label)
 arena.set_physics_process(true)
func run() -> void:
 arena=preload("res://scenes/arena.tscn").instantiate();arena.test_mode=true;root.add_child(arena)
 await frames(90)
 for brain in arena.ped_brains:brain.set_physics_process(false)
 var actor:CharacterMotor=arena.actor
 for direction in [Vector3.FORWARD,Vector3.BACK]:
  actor.respawn(Vector3(-25,3,35));actor.facing=0;actor.health.receive(10000)
  actor.reaction_body.launch_velocity(actor.global_position,0,direction*4)
  await frames(300)
  var p:=actor.reaction_body.global_position
  await capture("prone" if direction==Vector3.FORWARD else "supine",p+Vector3(-2.6,1.25,-2.0),p)
 for id in ["pcj600","sanchez","faggio","freeway"]:
  var bike:DriveVehicle=arena.get_node(id);bike.freeze=true
  actor.respawn(bike.approach_position()+Vector3(-0.7,0,0.3));await frames(35)
  arena.transition.request_enter(bike)
  await TransitionTestWait.approach(arena)
  await frames(ceili(arena.transition.enter_total*60)+4)
  arena.transition.request_eject();await frames(8)
  var p:=bike.seat_position()
  await capture(id+"-rear-bailout",p+Vector3(-2.6,1,-2.5),p)
  await frames(18)
  if arena.transition.state!="on_foot":arena.transition.recover()
 actor.respawn(Vector3(-25,0.94,35));await frames(35)
 var cmd:=GameplayCommand.new();cmd.move=Vector2(0,-1);cmd.sprint=true;await frames(80,cmd)
 await capture("sprint",actor.global_position+Vector3(-3,1,-2),actor.global_position)
 arena.queue_free();await process_frame;quit()
