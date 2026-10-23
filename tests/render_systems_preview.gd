extends SceneTree
var arena:Node3D
func _initialize() -> void:run.call_deferred()
func frames(count:int,cmd:GameplayCommand=null) -> void:
 arena.injected_command=cmd if cmd!=null else GameplayCommand.new()
 for i in range(count):await physics_frame;await process_frame
func capture(label:String,eye:Vector3,target:Vector3) -> void:
 arena.set_physics_process(false)
 arena.rig.camera.global_position=eye
 arena.rig.camera.look_at(target)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/systems-"+label+".png")
 print("CAPTURE ",label)
 arena.set_physics_process(true)
func run() -> void:
 arena=preload("res://scenes/arena.tscn").instantiate();arena.test_mode=true;root.add_child(arena)
 await frames(90)
 var actor:CharacterMotor=arena.actor
 actor.respawn(Vector3(-3,0.94,4));await frames(25)
 var crouch:=GameplayCommand.new();crouch.crouch=true;await frames(1,crouch)
 var aim:=GameplayCommand.new();aim.aim=true
 arena.rig.pitch=0
 await frames(20,aim)
 await capture("crouch-aim",Vector3(-5.5,1.3,1.7),actor.global_position+Vector3(0,-0.2,0))
 aim.fire=true;await frames(1,aim);aim.fire=false;await frames(2,aim)
 await capture("crouch-fire",Vector3(-5.5,1.3,1.7),actor.global_position+Vector3(0,-0.2,0))
 var prop:PhysicalProp=get_nodes_in_group("physical_props")[0]
 DamageEvent.deliver(prop,DamageEvent.make(25,prop.global_position+Vector3.UP*0.9,Vector3(1,0.1,0)))
 await frames(8)
 await capture("dynamic-bin",prop.global_position+Vector3(-3,1.6,2),prop.global_position+Vector3.UP*0.4)
 var car:DriveVehicle=arena.vehicle
 car.damage.burst_tire(0)
 car.damage.hit_glass(DamageEvent.make(25,car.global_position,Vector3.BACK))
 await frames(20)
 await capture("flat-cracked",car.global_position+Vector3(-3,1.6,-3),car.global_position+Vector3(0,0.2,-0.2))
 car.damage.hit_glass(DamageEvent.make(25,car.global_position,Vector3.BACK))
 await frames(2)
 await capture("shattered",car.global_position+Vector3(-2.8,1.4,-2.8),car.global_position+Vector3(0,0.3,-0.3))
 car.damage.repair()
 actor.respawn(car.approach_position(1));await frames(25)
 var seat:VehicleTransition=arena.transition
 seat.request_enter(car,true)
 await frames(ceili(seat.profile.enter_seconds*60)+15)
 await capture("passenger",car.global_position+Vector3(2.6,1.5,-1.5),car.seat_position(1)+Vector3.UP*0.2)
 seat.request_exit();await frames(ceili(seat.profile.exit_seconds*60)+10)
 actor.respawn(Vector3(-20,0.94,35));await frames(5)
 DamageEvent.deliver(car,DamageEvent.make(800,car.global_position,Vector3.FORWARD))
 await frames(45)
 await capture("burning",car.global_position+Vector3(-4,2,-4),car.global_position+Vector3.UP*0.4)
 await capture("variants",Vector3(8,9,43),Vector3(20,0.5,31))
 arena.queue_free();await process_frame;quit()
