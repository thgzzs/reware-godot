extends SceneTree
var arena: Node3D
func _initialize() -> void: run.call_deferred()
func run() -> void:
 arena=preload("res://scenes/arena.tscn").instantiate()
 arena.test_mode=true
 arena.enable_vehicle_fixtures=false
 root.add_child(arena)
 arena.injected_command=GameplayCommand.new()
 for i in range(30): await physics_frame; await process_frame
 var car: DriveVehicle=arena.vehicle
 arena.actor.respawn(Vector3(-20,0.94,35))
 DamageEvent.deliver(car,DamageEvent.make(800,car.global_position,Vector3.FORWARD))
 for i in range(60): await physics_frame; await process_frame
 arena.set_physics_process(false)
 arena.rig.camera.global_position=car.global_position+Vector3(-4,2,-4)
 arena.rig.camera.look_at(car.global_position+Vector3.UP*0.4)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/systems-burning.png")
 print("CAPTURE burning")
 arena.queue_free(); await process_frame; quit()
