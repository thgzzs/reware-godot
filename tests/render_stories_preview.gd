extends SceneTree
var arena:Node3D
var selection:="weapons"
func _initialize() -> void:run.call_deferred()
func frames(count:int,cmd:GameplayCommand=null) -> void:
 arena.injected_command=cmd if cmd!=null else GameplayCommand.new()
 for i in range(count):await physics_frame;await process_frame
func equip(id:String) -> void:
 for i in range(arena.weapon.inventory.size()):
  if arena.weapon.inventory[i].profile.id==id:arena.weapon.equip_slot(i);return
func capture(label:String,eye:Vector3,target:Vector3) -> void:
 arena.set_physics_process(false)
 arena.rig.camera.global_position=eye
 arena.rig.camera.look_at(target)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/stories-"+label+".png")
 print("CAPTURE ",label)
 arena.set_physics_process(true)
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--case="):selection=arg.trim_prefix("--case=")
 arena=preload("res://scenes/arena.tscn").instantiate();arena.test_mode=true;arena.enable_vehicle_fixtures=selection=="bikes";root.add_child(arena)
 await frames(80)
 for brain in arena.ped_brains:brain.set_physics_process(false)
 var actor:CharacterMotor=arena.actor
 if selection=="weapons":
  actor.respawn(Vector3(-3,0.94,4));arena.rig.yaw=0;arena.rig.pitch=0;await frames(35)
  var hip:=GameplayCommand.new();hip.move=Vector2(1,0);hip.walk=true;hip.fire=true
  await frames(60,hip)
  await capture("pistol-hipfire",actor.global_position+Vector3(-2.8,1.3,-2.3),actor.global_position+Vector3.UP*0.15)
  actor.respawn(Vector3(-3,0.94,4));actor.facing=0;await frames(35)
  equip("m4");var aim:=GameplayCommand.new();aim.aim=true;await frames(35,aim)
  await capture("m4-aim",actor.global_position+Vector3(-2.7,1.2,-2.5),actor.global_position+Vector3.UP*0.15)
  actor.respawn(Vector3(-3,0.94,4));actor.facing=0;await frames(35)
  equip("katana");arena.weapon.melee.recovery=0;arena.weapon.cooldown=0;arena.weapon.melee.combo=2
  var attack:=GameplayCommand.new();attack.fire=true;await frames(1,attack);await frames(24)
  await capture("katana-swing",actor.global_position+Vector3(-2.6,1.4,-2.5),actor.global_position+Vector3.UP*0.1)
 elif selection=="bikes":
  for id in ["pcj600","faggio"]:
   var bike:=arena.get_node(id) as DriveVehicle
   bike.freeze=true
   bike.damage.repair()
   actor.respawn(bike.approach_position())
   bike.reserve_seat(actor);bike.commit_seat(actor)
   actor.set_embarked(true)
   arena.transition.vehicle=bike;arena.transition.seat_index=0;arena.transition.state="driving"
   await frames(25)
   actor.reference_motion.vehicle_layers.clear()
   actor.reference_motion.set_clip(bike.bike_animation+"_Ride")
   actor.reference_motion.phase="seated";actor.reference_motion.time=0
   actor.reference_pose.sample_pose(0.3)
   arena.transition.align_to_seat()
   await capture(id+"-rider",bike.global_position+Vector3(-2.4,1.5,-2.5),bike.seat_position()+Vector3.UP*0.3)
   bike.release_seat(actor);arena.transition.vehicle=null;arena.transition.state="on_foot"
   actor.set_embarked(false)
  actor.respawn(Vector3(-24,0.94,38));await frames(2)
  await capture("bike-collection",Vector3(12,6,23),Vector3(14,0.8,14))
 elif selection=="exits":
  var car:DriveVehicle=arena.vehicle
  car.freeze=true
  car.global_transform=Transform3D(Basis(Vector3.FORWARD,PI),Vector3(1,1.3,0))
  actor.respawn(Vector3(-3,0.94,4))
  car.reserve_seat(actor);car.commit_seat(actor)
  actor.set_embarked(true)
  arena.transition.vehicle=car;arena.transition.seat_index=0;arena.transition.state="driving"
  await frames(3)
  if arena.transition.request_exit():
   await frames(ceili(arena.transition.exit_total*30))
   var outward:Vector3=arena.transition.exit_position-car.global_position
   outward.y=0;outward=outward.normalized()
   await capture("overturned-crawl",arena.transition.exit_position+outward*3+Vector3(0,1.4,-2),arena.transition.exit_position+Vector3.UP*0.15)
 elif selection=="damage":
  actor.respawn(Vector3(-24,0.94,38))
  var car:DriveVehicle=arena.vehicle
  car.freeze=true
  for id in ["bonnet","door_lf"]:
   var hit:=DamageEvent.make(50,car.global_transform*car.parts.parts[id].bounds.get_center(),Vector3.FORWARD,"melee",actor)
   hit.part=id;car.receive_hit(hit)
  car.damage.burst_tire(0)
  await frames(3)
  await capture("panel-damage",car.global_position+Vector3(-4,2,-4),car.global_position+Vector3.UP*0.3)
  var hit:=DamageEvent.make(100,car.global_transform*car.parts.parts.bonnet.bounds.get_center(),Vector3.FORWARD,"melee",actor);hit.part="bonnet";car.receive_hit(hit)
  await frames(10)
  await capture("detached-bonnet",car.global_position+Vector3(-4.5,2.7,-4.6),car.global_position+Vector3.UP*0.4)
 arena.queue_free();await process_frame;quit()
