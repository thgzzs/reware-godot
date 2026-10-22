extends SceneTree
var arena: Node3D
func _initialize() -> void: capture.call_deferred()
func settle() -> void:
 for i in range(4): await process_frame
 await RenderingServer.frame_post_draw
func save_image(path: String) -> void:
 var image := root.get_texture().get_image()
 if image==null or image.is_empty():
  push_error("No rendered viewport image")
  return
 image.save_png(path)
 print("CAPTURE ",path," ",image.get_size())
func capture() -> void:
 arena = preload("res://scenes/arena.tscn").instantiate()
 arena.test_mode = true
 root.add_child(arena)
 for i in range(60):
  await physics_frame
  await process_frame
 arena.set_physics_process(false)
 arena.actor.reference_motion.preview_clip = "IDLE_stance"
 arena.actor.reference_motion.preview_time = 0
 arena.actor.reference_motion.preview_playing = false
 arena.rig.camera.global_position = Vector3(-6,3.0,8)
 arena.rig.camera.look_at(Vector3(-1,1.1,1))
 await settle()
 save_image("res://docs/model-preview.png")
 arena.overlay.toggle_settings()
 await settle()
 save_image("res://docs/display-preview.png")
 arena.overlay.toggle_settings()
 root.size = Vector2i(1024,768)
 await settle()
 save_image("res://docs/aspect-4-3-preview.png")
 root.size = Vector2i(1600,720)
 await settle()
 save_image("res://docs/aspect-wide-preview.png")
 root.size = Vector2i(600,900)
 await settle()
 save_image("res://docs/aspect-portrait-preview.png")
 arena.animation_browser.toggle()
 arena.animation_browser.refilter("walk")
 arena.animation_browser.select(0)
 await settle()
 save_image("res://docs/animation-browser-preview.png")
 arena.queue_free()
 await process_frame
 quit()
