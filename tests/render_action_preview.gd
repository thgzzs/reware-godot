extends SceneTree
var arena: Node3D
func _initialize() -> void: capture.call_deferred()
func frames(count: int) -> void:
 for i in range(count):
  await physics_frame
  await process_frame
func save_image(name: String) -> void:
 await frames(3)
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 if image==null or image.is_empty():push_error("No rendered action image"); return
 image.save_png("res://docs/revision-"+name+"-preview.png")
 print("CAPTURE ",name)
func capture() -> void:
 arena = preload("res://scenes/arena.tscn").instantiate()
 arena.test_mode = true
 root.add_child(arena)
 await frames(70)
 arena.set_physics_process(false)
 for brain in arena.ped_brains: brain.set_physics_process(false)
 var actor: CharacterMotor = arena.actor
 var visual: SkinnedMotionVisual = actor.reference_pose
 visual.set_process(false)
 actor.reset_at(Vector3(-3,0.94,4))
 actor.visual.rotation.y = 0
 arena.rig.camera.global_position = Vector3(-5.8,2.0,1.2)
 arena.rig.camera.look_at(actor.global_position+Vector3(0,0.15,0))
 var motion := actor.reference_motion
 motion.phase = "move"; motion.intensity = 1.5; motion.cycle = 0.3; motion.was_sprinting = false
 actor.actions.aim_weight = 1
 actor.actions.aim_pitch = 0
 visual.sample_pose(0.2)
 await save_image("aim-walk")
 actor.actions.reloading = true
 actor.actions.reload_weight = 1
 actor.actions.reload_time = 0.25
 visual.sample_pose(0.2)
 await save_image("reload")
 actor.health.receive(1000)
 actor.actions.life = "dead"
 motion.phase = "dead"
 motion.set_clip(actor.actions.life_clip)
 motion.time = motion.duration(actor.actions.life_clip)
 actor.grounded = true
 visual.sample_pose(0.4)
 arena.rig.camera.global_position = Vector3(-5.5,1.6,6)
 arena.rig.camera.look_at(actor.global_position+Vector3(0,-0.65,-0.5))
 await save_image("death")
 actor.respawn(Vector3(-3,0.94,4))
 actor.visible = false
 arena.vehicle.set_door_open(0,true)
 await frames(80)
 arena.rig.camera.global_position = Vector3(-3.8,2.1,-3)
 arena.rig.camera.look_at(arena.vehicle.global_position)
 await save_image("door")
 actor.visible = true
 var seat: VehicleTransition = arena.transition
 actor.reset_at(arena.vehicle.approach_position())
 actor.grounded = true
 seat.request_enter(arena.vehicle)
 for i in range(ceili((seat.profile.enter_open_seconds+0.3)*60)):
  seat.tick(1.0/60)
  visual.sample_pose(1.0/60)
  await frames(1)
 await save_image("entry")
 arena.queue_free();await process_frame;quit()
