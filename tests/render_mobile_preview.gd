extends SceneTree
var arena:Node3D
func _initialize() -> void:run.call_deferred()
func frames(n:int,cmd:GameplayCommand=null) -> void:
 arena.injected_command=cmd if cmd!=null else GameplayCommand.new()
 for i in range(n):await physics_frame;await process_frame
func capture(label:String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/mobile-"+label+".png")
 print("CAPTURE ",label)
func run() -> void:
 arena=preload("res://scenes/arena.tscn").instantiate();arena.test_mode=true;arena.force_touch_controls=true;root.add_child(arena)
 await frames(60)
 for brain in arena.ped_brains:brain.set_physics_process(false)
 await capture("on-foot-wide")
 arena.overlay.toggle_settings();await frames(3);await capture("settings-wide")
 arena.overlay.toggle_settings();await frames(2)
 arena.actor.respawn(arena.vehicle.approach_position());await frames(30)
 arena.transition.request_enter(arena.vehicle);await TransitionTestWait.approach(arena)
 for i in range(200):
  if arena.transition.state=="driving":break
  await frames(1)
 await frames(4);await capture("driving-wide")
 root.size=Vector2i(1280,720);await frames(3);await capture("driving-16x9")
 arena.queue_free();await process_frame;quit()
