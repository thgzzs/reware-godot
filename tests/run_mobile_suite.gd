extends SceneTree
var arena:Node3D
var results:Array[Dictionary]=[]
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(label:String,passed:bool,value:Variant=null) -> void:
 results.append({"name":label,"passed":passed,"measured":value})
 if not passed:failures+=1
 print("PASS " if passed else "FAIL ",label," ",value)
func frames(count:int) -> void:
 for i in range(count):await physics_frame;await process_frame
func touch(index:int,at:Vector2,pressed:bool) -> void:
 var e:=InputEventScreenTouch.new();e.index=index;e.position=at;e.pressed=pressed;root.push_input(e,true)
func drag(index:int,at:Vector2,relative:Vector2) -> void:
 var e:=InputEventScreenDrag.new();e.index=index;e.position=at;e.relative=relative;root.push_input(e,true)
func run() -> void:
 var state:=TouchIntent.new()
 state.press("jump");state.release("jump")
 check("a complete tap between physics ticks preserves its edge",state.apply(GameplayCommand.new()).jump)
 check("one-shot actions consume their edge exactly once",not state.apply(GameplayCommand.new()).jump)
 state.press("fire");state.press("fire");state.release("fire")
 check("releasing one finger preserves another held action",state.apply(GameplayCommand.new()).fire)
 state.release("fire");check("last release stops held firing",not state.apply(GameplayCommand.new()).fire)
 state.press("fire");state.release("fire")
 check("a quick fire tap survives an entire input frame",state.apply(GameplayCommand.new()).fire)
 state.press("aim");state.release("aim")
 check("aim toggle survives finger release",state.apply(GameplayCommand.new()).aim)
 state.press("aim");state.release("aim")
 check("a second aim tap returns to hip fire",not state.apply(GameplayCommand.new()).aim)
 state.press("sprint");state.release("sprint")
 check("sprint taps preserve a distinct press edge",state.apply(GameplayCommand.new()).sprint_pressed)
 state.driving=true;state.move=Vector2(0.5,-1);state.press("throttle")
 var cmd:=state.apply(GameplayCommand.new())
 check("vehicle throttle combines with analog steering",cmd.move.x>0.4 and cmd.move.y< -0.8,cmd.move)
 state.release("throttle");state.press("reverse");state.press("brake");cmd=state.apply(GameplayCommand.new())
 check("reverse and brake are independent vehicle actions",cmd.move.y>0.8 and cmd.brake)
 state.look=Vector2(10,5);state.clear();cmd=state.apply(GameplayCommand.new())
 check("clearing touch intent removes all held/toggle/edge/look state",cmd.move==Vector2.ZERO and cmd.look==Vector2.ZERO and not cmd.aim and not cmd.brake and not cmd.fire)
 arena=preload("res://scenes/arena.tscn").instantiate();arena.force_touch_controls=true;arena.enable_reference_assets=false;arena.enable_vehicle_fixtures=false;arena.test_mode=true
 root.add_child(arena);arena.test_mode=false;await frames(80)
 var ui:MobileControls=arena.mobile_controls
 var actor:CharacterMotor=arena.actor
 actor.respawn(Vector3(-25,0.94,40));await frames(30)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 check("touch mode runs with a visible cursor and the normal input producer",arena.uses_touch_controls() and arena.input_source.touch==ui.intent and not arena.test_mode)
 var original:=actor.global_position
 touch(0,ui.stick_center+Vector2(0,-ui.stick_radius),true);await frames(1)
 check("screen-touch movement owns one stick finger",ui.has_role("stick") and ui.intent.move.y< -0.99)
 var camera_point:=Vector2(ui.safe.get_center().x+15,ui.safe.position.y+250)
 touch(1,camera_point,true);var yaw:float=arena.rig.yaw
 drag(1,camera_point+Vector2(45,-10),Vector2(45,-10));await frames(1)
 check("camera drag is independent from the movement finger",arena.rig.yaw<yaw-0.05 and ui.intent.move.y< -0.99)
 touch(2,ui.buttons.aim.get_center(),true);touch(2,ui.buttons.aim.get_center(),false)
 var shots:int=arena.weapon.shots
 touch(3,ui.buttons.fire.get_center(),true);await frames(30)
 check("simultaneous move/aim/fire uses the live gameplay loop",arena.weapon.shots>shots and actor.global_position.distance_to(original)>1 and actor.actions.aim_weight>0.5,{"shots":arena.weapon.shots-shots,"distance":actor.global_position.distance_to(original)})
 touch(3,ui.buttons.fire.get_center(),false);touch(1,camera_point,false);touch(0,ui.stick_center,false);await frames(3)
 check("touch release stops movement and firing",ui.intent.move==Vector2.ZERO and not ui.intent.down("fire") and ui.owners.is_empty())
 ui.clear();touch(0,ui.stick_center+Vector2(ui.stick_radius*0.05,0),true);await frames(1)
 check("stick deadzone filters thumb jitter",ui.intent.move==Vector2.ZERO)
 touch(0,ui.stick_center,false);await frames(1)
 touch(4,ui.buttons.sprint.get_center(),true);await frames(1)
 drag(4,ui.safe.position,Vector2.ZERO);await frames(1)
 check("dragging out of a button releases its held action",not ui.intent.down("sprint"))
 touch(4,ui.safe.position,false);await frames(1)
 touch(0,ui.stick_center+Vector2(0,-ui.stick_radius),true);touch(3,ui.buttons.fire.get_center(),true);await frames(1)
 ui.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);await frames(1)
 check("focus loss clears held touches without requiring release events",ui.owners.is_empty() and ui.intent.move==Vector2.ZERO and not ui.intent.down("fire"))
 touch(5,ui.buttons.settings.get_center(),true);await frames(1)
 check("touch menu opens the existing display panel",arena.overlay.settings.visible and not ui.visible)
 touch(5,ui.buttons.settings.get_center(),false);await frames(1)
 var before:=actor.global_position;touch(0,ui.stick_center-Vector2(0,ui.stick_radius),true);await frames(20)
 check("modal UI blocks game touches and clears previous movement",actor.global_position.distance_to(before)<0.1 and ui.owners.is_empty())
 touch(0,ui.stick_center-Vector2(0,ui.stick_radius),false);await frames(1)
 var slider_rect:Rect2=arena.overlay.render_slider.get_global_rect()
 var from:=slider_rect.position+Vector2(slider_rect.size.x*0.2,slider_rect.size.y*0.5)
 var to:=slider_rect.position+Vector2(slider_rect.size.x*0.7,slider_rect.size.y*0.5)
 touch(10,from,true);await frames(1);drag(10,to,to-from);await frames(1);touch(10,to,false);await frames(2)
 check("touch drags adjust the native render-scale slider",arena.display_controller.current_scale>0.65 and arena.display_controller.current_scale<0.95,arena.display_controller.current_scale)
 var resume:Button
 for child in arena.overlay.settings.find_children("*","Button",true,false):
  if child.text.begins_with("Resume"):resume=child
 touch(5,resume.get_global_rect().get_center(),true);touch(5,resume.get_global_rect().get_center(),false);await frames(2)
 check("modal controls accept touch while gameplay mouse emulation stays off",not arena.overlay.settings.visible)
 check("resuming on mobile does not require mouse capture",Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and ui.visible)
 var safe_before:=ui.safe
 ui.safe_override=Rect2(Vector2(70,40),get_root().get_visible_rect().size-Vector2(110,70));ui.update_layout()
 check("touch layout respects display cutout bounds",ui.safe.position.x>=70 and ui.safe.position.y>=40 and ui.safe.end.x<=safe_before.end.x)
 var inside:=true;var overlaps:=false;var keys:=ui.buttons.keys()
 for i in range(keys.size()):
  var a:Rect2=ui.buttons[keys[i]];inside=inside and ui.safe.encloses(a)
  for j in range(i):overlaps=overlaps or a.intersects(ui.buttons[keys[j]])
 check("action targets remain inside safe bounds without overlap",inside and not overlaps)
 ui.safe_override=Rect2();ui.update_layout()
 actor.respawn(arena.vehicle.approach_position());await frames(30)
 touch(6,ui.buttons.interact.get_center(),true);touch(6,ui.buttons.interact.get_center(),false);await frames(1)
 check("touch entry starts the existing seat transaction",arena.transition.state in ["approaching","entering"])
 for i in range(650):
  if arena.transition.state=="driving":break
  await frames(1)
 check("touch entry commits unique vehicle ownership",arena.transition.state=="driving" and arena.vehicle.driver==actor)
 check("driving context swaps combat buttons for vehicle controls",ui.buttons.has("throttle") and ui.buttons.has("reverse") and ui.buttons.has("brake") and not ui.buttons.has("fire"))
 touch(0,ui.stick_center+Vector2(ui.stick_radius*0.5,0),true);touch(7,ui.buttons.throttle.get_center(),true);await frames(90)
 check("touch gas and steering drive the real Jolt vehicle",arena.vehicle.speed>3 and arena.vehicle.steering_input< -0.2,{"speed":arena.vehicle.speed,"steer":arena.vehicle.steering_input})
 touch(0,ui.stick_center,false);touch(7,ui.buttons.throttle.get_center(),false);await frames(2)
 touch(8,ui.buttons.brake.get_center(),true);var speed:float=arena.vehicle.speed;await frames(45)
 check("touch brake slows the vehicle",absf(arena.vehicle.speed)<absf(speed),[speed,arena.vehicle.speed])
 touch(8,ui.buttons.brake.get_center(),false);await frames(2)
 ui.clear();arena.vehicle.freeze=true;arena.vehicle.linear_velocity=Vector3.ZERO;await frames(2)
 touch(6,ui.buttons.interact.get_center(),true);touch(6,ui.buttons.interact.get_center(),false);await frames(100)
 check("touch exit restores on-foot controls and releases occupancy",arena.transition.state=="on_foot" and actor.control_enabled and arena.vehicle.driver==null and ui.buttons.has("jump"))
 actor.health.receive(10000);await frames(2)
 check("death exposes a reachable touch respawn action",ui.buttons.has("respawn") and not ui.buttons.has("fire"))
 touch(9,ui.buttons.respawn.get_center(),true);touch(9,ui.buttons.respawn.get_center(),false);await frames(5)
 check("touch respawn restores the continuous gameplay loop",actor.health.health==100 and actor.control_enabled and ui.buttons.has("fire"))
 var report:={"engine":Engine.get_version_info().string,"backend":"Jolt Physics","assertions":results.size(),"failures":failures,"results":results,"android_device_tested":false,"scope":"Real ScreenTouch/ScreenDrag events through the live command producer, primitive/Jolt gameplay; native regression runs separately"}
 FileAccess.open("res://tests/mobile_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("RESULT mobile ",results.size()," / failures ",failures)
 arena.queue_free();await process_frame;quit(1 if failures else 0)
