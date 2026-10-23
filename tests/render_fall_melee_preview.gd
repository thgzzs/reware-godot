extends SceneTree
var arena:Node3D
func _initialize() -> void:run.call_deferred()
func frames(count:int,cmd:GameplayCommand=null) -> void:
 arena.injected_command=cmd if cmd!=null else GameplayCommand.new()
 for i in range(count):await physics_frame;await process_frame
func capture(label:String) -> void:
 var actor:CharacterMotor=arena.actor
 arena.set_physics_process(false)
 arena.rig.camera.global_position=actor.global_position+Vector3(-3,1.25,-2.5)
 arena.rig.camera.look_at(actor.global_position+Vector3.UP*0.1)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/fall-"+label+".png")
 print("CAPTURE ",label)
 arena.set_physics_process(true)
func run() -> void:
 arena=preload("res://scenes/arena.tscn").instantiate();arena.test_mode=true;arena.enable_vehicle_fixtures=false;root.add_child(arena)
 await frames(80)
 for brain in arena.ped_brains:brain.set_physics_process(false)
 var actor:CharacterMotor=arena.actor
 actor.respawn(Vector3(-20,12,32));await frames(45)
 await capture("descent")
 actor.respawn(Vector3(-20,4.94,32))
 for i in range(100):
  await frames(1)
  if actor.fall.hard_landing:break
 await frames(12)
 await capture("landing")
 for id in ["baseballbat","katana"]:
  actor.respawn(Vector3(-20,0.94,32));actor.facing=0;actor.visual.rotation.y=0;await frames(35)
  for i in range(arena.weapon.inventory.size()):
   if arena.weapon.inventory[i].profile.id==id:arena.weapon.equip_slot(i)
  arena.weapon.cooldown=0;arena.weapon.melee.recovery=0;arena.weapon.melee.combo=0
  var cmd:=GameplayCommand.new();cmd.move=Vector2(0,-1);await frames(60,cmd)
  cmd.fire=true;await frames(20,cmd)
  await capture(id+"-running")
 arena.queue_free();await process_frame;quit()
