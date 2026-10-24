extends SceneTree
var arena:Node3D
func _initialize() -> void:run.call_deferred()
func frames(count:int,cmd:GameplayCommand=null) -> void:
 arena.injected_command=cmd if cmd!=null else GameplayCommand.new()
 for i in range(count):await physics_frame;await process_frame
func equip(id:String) -> void:
 for i in range(arena.weapon.inventory.size()):
  if arena.weapon.inventory[i].profile.id==id:arena.weapon.equip_slot(i);return
func capture(label:String,offset:=Vector3(-2.4,1.0,-2.3)) -> void:
 arena.set_physics_process(false)
 arena.rig.camera.global_position=arena.actor.global_position+offset
 arena.rig.camera.look_at(arena.actor.global_position+Vector3.UP*0.1)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/behavior-"+label+".png")
 print("CAPTURE ",label)
 arena.set_physics_process(true)
func run() -> void:
 arena=preload("res://scenes/arena.tscn").instantiate();arena.test_mode=true;root.add_child(arena);await frames(90)
 for brain in arena.ped_brains:brain.set_physics_process(false)
 var actor:CharacterMotor=arena.actor
 var cmd:=GameplayCommand.new();cmd.aim=true
 for id in ["m4","shotgun"]:
  actor.respawn(Vector3(-20,0.94,38));actor.facing=0;actor.visual.rotation.y=0;arena.rig.yaw=0;arena.rig.pitch=0;equip(id);await frames(40,cmd)
  await capture(id+"-aim")
 cmd.crouch=true;await frames(1,cmd);cmd.crouch=false;await frames(35,cmd);await capture("legacy-crouch")
 actor.respawn(Vector3(-20,0.94,38));await frames(30)
 actor.receive_hit(DamageEvent.make(12,actor.global_position,Vector3.BACK,"bullet"));await frames(10);await capture("hit-reaction")
 actor.respawn(Vector3(-20,1.59,38))
 for i in range(80):
  await frames(1)
  if actor.landing.weight>0.7:break
 await capture("soft-landing")
 actor.respawn(Vector3(-20,0.94,38));await frames(30)
 var ped:CharacterMotor=arena.pedestrians[0]
 ped.respawn(actor.global_position+Vector3(0,0,-0.6));ped.receive_hit(DamageEvent.make(1000,ped.global_position,Vector3.FORWARD,"bullet"))
 for i in range(160):ped.tick(GameplayCommand.new(),0,1.0/60);await frames(1)
 for id in ["unarmed","baseballbat"]:
  actor.respawn(ped.global_position+Vector3(0,0,0.45));actor.facing=0;await frames(30);equip(id);arena.weapon.melee.recovery=0;arena.weapon.melee.request();await frames(22)
  await capture("ground-"+id,Vector3(-2.3,1.4,2.5))
 var bike:DriveVehicle=arena.get_node("pcj600")
 bike.reset_at(Vector3(-14,0.6,38));bike.reset_transform.basis=Basis(Vector3.FORWARD,1.2);await frames(120)
 actor.respawn(bike.approach_position(0,0));await frames(30);arena.transition.request_enter(bike)
 for i in range(350):
  await frames(1)
  if arena.transition.state=="lifting" and arena.transition.lift_elapsed>0.65:break
 await capture("bike-pickup",Vector3(-3,1.2,2.5))
 for i in range(500):
  await frames(1)
  if arena.transition.state in ["driving","on_foot"]:break
 cmd=GameplayCommand.new();cmd.move=Vector2(0,1);await frames(80,cmd);await capture("bike-walkback",Vector3(-3,1.2,2.5))
 arena.queue_free();await process_frame;quit()
