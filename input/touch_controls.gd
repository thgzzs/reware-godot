class_name MobileControls
extends Control
## A finger retains its role until release. Buttons never steal camera/stick fingers.
var arena:Node3D
var enabled:=false
var intent:=TouchIntent.new()
var owners:Dictionary={}
var buttons:Dictionary={}
var labels:Dictionary={}
var safe:=Rect2()
var stick_center:=Vector2.ZERO
var stick_radius:=76.0
var stick_zone:=Rect2()
var look_zone:=Rect2()
var mode:=""
var blocked:=false
var safe_override:=Rect2()
var modal_finger := -1
func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 visible=enabled
 get_viewport().size_changed.connect(update_layout)
 sync_context()
func clear() -> void:
 if modal_finger>=0:
  modal_finger=-1
  gui_pointer(Vector2(-1000,-1000),false)
 owners.clear();intent.clear();queue_redraw()
func sync_context() -> void:
 if not is_instance_valid(arena)or not is_instance_valid(arena.actor):return
 var next:String="dead" if arena.actor.health.health<=0 else arena.transition.state
 var next_blocked:bool=arena.overlay.settings.visible or (is_instance_valid(arena.animation_browser)and arena.animation_browser.visible)
 var changed:=next!=mode or next_blocked!=blocked
 if changed:
  clear();mode=next;blocked=next_blocked
 intent.driving=mode in ["driving","passenger"]
 visible=enabled and not blocked
 if changed or buttons.is_empty():update_layout()
func update_layout() -> void:
 var screen:=get_viewport_rect().size
 safe=Rect2(Vector2.ONE*intent.profile.margin,screen-Vector2.ONE*intent.profile.margin*2)
 if safe_override.has_area():safe=safe.intersection(safe_override)
 elif OS.has_feature("mobile"):
  var display_safe:=DisplayServer.get_display_safe_area()
  if display_safe.has_area():
   var viewport_safe:Rect2=get_viewport().get_screen_transform().affine_inverse()*Rect2(display_safe)
   safe=safe.intersection(viewport_safe)
 var scale_factor:=clampf(safe.size.y/684.0,0.6,1.35)
 stick_radius=intent.profile.stick_radius*scale_factor
 stick_center=Vector2(safe.position.x+112*scale_factor,safe.end.y-128*scale_factor)
 stick_zone=Rect2(safe.position+Vector2(0,safe.size.y*0.38),Vector2(safe.size.x*0.43,safe.size.y*0.62))
 look_zone=Rect2(Vector2(safe.position.x+safe.size.x*0.43,safe.position.y+130*scale_factor),Vector2(safe.size.x*0.57,safe.size.y-130*scale_factor))
 buttons.clear();labels.clear()
 add_button("settings","MENU",Vector2(safe.position.x+268*scale_factor,safe.position.y+34*scale_factor),31*scale_factor)
 add_button("camera_cycle","CAM",Vector2(safe.position.x+344*scale_factor,safe.position.y+34*scale_factor),31*scale_factor)
 if mode=="dead":
  add_button("respawn","RESPAWN",safe.end-Vector2(110,90)*scale_factor,48*scale_factor)
 elif mode in ["driving","passenger"]:
  add_button("interact","EXIT",safe.end-Vector2(62,285)*scale_factor,32*scale_factor)
  add_button("switch_seat","SEAT",safe.end-Vector2(145,285)*scale_factor,30*scale_factor)
  if mode=="driving":
   add_button("throttle","GAS",safe.end-Vector2(62,64)*scale_factor,40*scale_factor)
   add_button("brake","BRAKE",safe.end-Vector2(155,130)*scale_factor,35*scale_factor)
   add_button("reverse","REV",safe.end-Vector2(62,180)*scale_factor,35*scale_factor)
 elif mode in ["approaching","lifting"]:
  add_button("interact","CANCEL",safe.end-Vector2(62,285)*scale_factor,34*scale_factor)
 elif mode=="on_foot":
  for item in [["fire","FIRE",Vector2(62,185),38],["aim","AIM",Vector2(145,118),32],["jump","JUMP",Vector2(62,55),32],["sprint","SPRINT",Vector2(225,55),33],["crouch","CROUCH",Vector2(225,135),32],["reload","LOAD",Vector2(145,217),30],["interact","ENTER",Vector2(62,285),32],["weapon_previous","‹",Vector2(300,217),27],["weapon_next","›",Vector2(225,217),27]]:
   add_button(item[0],item[1],safe.end-item[2]*scale_factor,float(item[3])*scale_factor)
func add_button(action:String,label:String,center:Vector2,radius:float) -> void:
 buttons[action]=Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2)
 labels[action]=label
func _process(_dt:float) -> void:
 if not enabled:return
 sync_context();queue_redraw()
func _notification(what:int) -> void:
 if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:clear()
func _input(event:InputEvent) -> void:
 if not enabled:return
 sync_context()
 if blocked:
  # Gameplay suppresses touch-to-mouse emulation. Bridge one modal finger
  # explicitly so ordinary Godot sliders/buttons remain usable in settings.
  if event is InputEventScreenTouch:
   if event.pressed and modal_finger<0:
    modal_finger=event.index;gui_pointer(event.position,true)
   elif not event.pressed and event.index==modal_finger:
    modal_finger=-1;gui_pointer(event.position,false)
   get_viewport().set_input_as_handled()
  elif event is InputEventScreenDrag and event.index==modal_finger:
   var motion:=InputEventMouseMotion.new();motion.position=event.position;motion.global_position=event.position;motion.relative=event.relative;motion.button_mask=MOUSE_BUTTON_MASK_LEFT
   get_viewport().push_input.call_deferred(motion,true)
   get_viewport().set_input_as_handled()
  return
 if event is InputEventScreenTouch:
  if event.pressed:
   for action in buttons:
    if buttons[action].has_point(event.position):
     if action=="settings":arena.overlay.toggle_settings();clear()
     else:owners[event.index]={"role":action,"inside":true};intent.press(action)
     get_viewport().set_input_as_handled();return
   if mode in ["on_foot","driving"] and stick_zone.has_point(event.position) and not has_role("stick"):
    owners[event.index]={"role":"stick"};set_stick(event.position)
   elif look_zone.has_point(event.position) and not has_role("look"):
    owners[event.index]={"role":"look"}
   else:return
  elif owners.has(event.index):
   var role:String=owners[event.index].role
   if role=="stick":intent.move=Vector2.ZERO
   elif role!="look" and owners[event.index].get("inside",false):intent.release(role)
   owners.erase(event.index)
  else:return
  get_viewport().set_input_as_handled()
 elif event is InputEventScreenDrag and owners.has(event.index):
  var owner:Dictionary=owners[event.index];var role:String=owner.role
  if role=="stick":set_stick(event.position)
  elif role=="look":intent.look+=event.relative
  elif buttons.has(role):
   var inside:bool=buttons[role].has_point(event.position)
   if inside!=owner.inside:
    if inside:intent.press(role)
    else:intent.release(role)
    owner.inside=inside
  get_viewport().set_input_as_handled()
func gui_pointer(at:Vector2,pressed:bool) -> void:
 var motion:=InputEventMouseMotion.new();motion.position=at;motion.global_position=at
 get_viewport().push_input.call_deferred(motion,true)
 var button:=InputEventMouseButton.new();button.position=at;button.global_position=at;button.button_index=MOUSE_BUTTON_LEFT;button.pressed=pressed
 get_viewport().push_input.call_deferred(button,true)
func has_role(role:String) -> bool:
 for owner in owners.values():
  if owner.role==role:return true
 return false
func set_stick(at:Vector2) -> void:
 var axis:=((at-stick_center)/stick_radius).limit_length(1)
 var magnitude:=axis.length()
 intent.move=axis.normalized()*clampf((magnitude-intent.profile.deadzone)/(1-intent.profile.deadzone),0,1) if magnitude>intent.profile.deadzone else Vector2.ZERO
func _draw() -> void:
 if not enabled or blocked or buttons.is_empty():return
 var ink:=Color("b7e6ee");var accent:=Color("ed95bd")
 if mode in ["on_foot","driving"]:
  draw_circle(stick_center,stick_radius,Color(0.02,0.04,0.07,0.32))
  draw_arc(stick_center,stick_radius,0,TAU,48,Color(0.7,0.9,0.95,0.5),2,true)
  var axis:=Vector2(intent.move.x,0) if intent.driving else intent.move
  draw_circle(stick_center+axis*stick_radius*0.65,stick_radius*0.35,Color(0.7,0.9,0.95,0.48))
 for action in buttons:
  var rect:Rect2=buttons[action];var radius:=rect.size.x*0.5
  var down:bool=intent.down(action)or(action=="aim"and intent.aim_latched)
  draw_circle(rect.get_center(),radius,Color(0.15,0.25,0.33,0.75)if down else Color(0.02,0.04,0.07,0.42))
  draw_arc(rect.get_center(),radius,0,TAU,40,accent if down else Color(0.7,0.9,0.95,0.55),2,true)
  var font:=ThemeDB.fallback_font;var pixels:=maxi(12,int(radius*0.42));var text_size:=font.get_string_size(labels[action],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels)
  draw_string(font,rect.get_center()+Vector2(-text_size.x*0.5,text_size.y*0.25),labels[action],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,accent if down else ink)
