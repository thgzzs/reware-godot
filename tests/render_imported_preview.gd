extends SceneTree
func _initialize() -> void: capture.call_deferred()
func capture() -> void:
 var arena := preload("res://scenes/arena.tscn").instantiate()
 arena.test_mode = true
 root.add_child(arena)
 for i in range(60):
  await physics_frame
  await process_frame
 arena.set_physics_process(false)
 arena.actor.reference_motion.preview_clip = "WALK_player"
 arena.actor.reference_motion.preview_time = 0.4
 arena.actor.reference_motion.preview_playing = false
 arena.rig.camera.global_position = Vector3(-6,3.0,9)
 arena.rig.camera.look_at(Vector3(-2,1.0,2))
 for i in range(3): await process_frame
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 if image==null or image.is_empty():
  push_error("No rendered viewport image")
  quit(1)
  return
 image.save_png("res://docs/imported-preview.png")
 arena.animation_browser.visible = true
 arena.animation_browser.refilter("walk")
 arena.animation_browser.picker.select(0)
 arena.animation_browser.select(0)
 for i in range(3): await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/animation-browser.png")
 print("Rendered imported asset preview and animation browser")
 arena.queue_free()
 await process_frame
 quit()
