class_name LocalInputSource
extends RefCounted
var mouse_delta := Vector2.ZERO
var touch: TouchIntent
func install() -> void:
 var bindings := {"left":KEY_A,"right":KEY_D,"forward":KEY_W,"back":KEY_S,"jump":KEY_SPACE,"interact":KEY_E,"reload":KEY_R,"sprint":KEY_SHIFT,"walk":KEY_ALT,"brake":KEY_SPACE,"debug":KEY_F3,"crouch":KEY_C,"camera_cycle":KEY_V,"switch_seat":KEY_X,"repair_vehicle":KEY_F6}
 for action in bindings:
  if not InputMap.has_action(action):
   InputMap.add_action(action,0.2 if action in ["left","right","forward","back"] else 0.5)
   var event := InputEventKey.new()
   event.physical_keycode = bindings[action]
   InputMap.action_add_event(action,event)
 for pair in [["fire",MOUSE_BUTTON_LEFT],["aim",MOUSE_BUTTON_RIGHT]]:
  if not InputMap.has_action(pair[0]):
   InputMap.add_action(pair[0])
   var event := InputEventMouseButton.new()
   event.button_index = pair[1]
   InputMap.action_add_event(pair[0],event)
 for pair in [["weapon_next",KEY_Q],["weapon_previous",KEY_Z],["respawn",KEY_BACKSPACE]]:
  if not InputMap.has_action(pair[0]):
   InputMap.add_action(pair[0])
   var key := InputEventKey.new()
   key.physical_keycode = pair[1]
   InputMap.action_add_event(pair[0],key)
 for pair in [["weapon_next",MOUSE_BUTTON_WHEEL_UP],["weapon_previous",MOUSE_BUTTON_WHEEL_DOWN]]:
  var wheel := InputEventMouseButton.new()
  wheel.button_index = pair[1]
  if not InputMap.action_has_event(pair[0],wheel): InputMap.action_add_event(pair[0],wheel)
 for i in range(9):
  var action := "weapon_slot_%d"%i
  if not InputMap.has_action(action):
   InputMap.add_action(action)
   var key := InputEventKey.new()
   key.physical_keycode = KEY_1+i
   InputMap.action_add_event(action,key)
 install_gamepad()
func add_binding(action:String,event:InputEvent,deadzone:=0.2) -> void:
 if not InputMap.has_action(action):InputMap.add_action(action,deadzone)
 if not InputMap.action_has_event(action,event):InputMap.action_add_event(action,event)
func install_gamepad() -> void:
 # Add defaults once; retain all existing keyboard, mouse and user bindings.
 for row in [["left",JOY_AXIS_LEFT_X,-1.0],["right",JOY_AXIS_LEFT_X,1.0],["forward",JOY_AXIS_LEFT_Y,-1.0],["back",JOY_AXIS_LEFT_Y,1.0],["look_left",JOY_AXIS_RIGHT_X,-1.0],["look_right",JOY_AXIS_RIGHT_X,1.0],["look_up",JOY_AXIS_RIGHT_Y,-1.0],["look_down",JOY_AXIS_RIGHT_Y,1.0],["aim",JOY_AXIS_TRIGGER_LEFT,1.0],["fire",JOY_AXIS_TRIGGER_RIGHT,1.0]]:
  var axis:=InputEventJoypadMotion.new()
  axis.axis=row[1];axis.axis_value=row[2]
  add_binding(row[0],axis)
 for row in [["jump",JOY_BUTTON_A],["brake",JOY_BUTTON_A],["interact",JOY_BUTTON_Y],["reload",JOY_BUTTON_X],["crouch",JOY_BUTTON_B],["sprint",JOY_BUTTON_LEFT_STICK],["camera_cycle",JOY_BUTTON_RIGHT_STICK],["weapon_previous",JOY_BUTTON_LEFT_SHOULDER],["weapon_next",JOY_BUTTON_RIGHT_SHOULDER]]:
  var button:=InputEventJoypadButton.new()
  button.button_index=row[1]
  add_binding(row[0],button)
func sample() -> GameplayCommand:
 var cmd := GameplayCommand.new()
 cmd.move = Input.get_vector("left","right","forward","back")
 cmd.jump = Input.is_action_just_pressed("jump")
 cmd.crouch = Input.is_action_just_pressed("crouch")
 cmd.camera_cycle = Input.is_action_just_pressed("camera_cycle")
 cmd.repair_vehicle = Input.is_action_just_pressed("repair_vehicle")
 cmd.switch_seat = Input.is_action_just_pressed("switch_seat")
 cmd.interact = Input.is_action_just_pressed("interact")
 cmd.reload = Input.is_action_just_pressed("reload")
 cmd.aim = Input.is_action_pressed("aim")
 cmd.fire = Input.is_action_pressed("fire")
 cmd.walk = Input.is_action_pressed("walk")
 cmd.sprint = Input.is_action_pressed("sprint")
 cmd.sprint_pressed = Input.is_action_just_pressed("sprint")
 cmd.brake = Input.is_action_pressed("brake")
 cmd.look = mouse_delta
 cmd.look_stick = Input.get_vector("look_left","look_right","look_up","look_down")
 cmd.weapon_step = int(Input.is_action_just_pressed("weapon_next"))-int(Input.is_action_just_pressed("weapon_previous"))
 for i in range(9):
  if Input.is_action_just_pressed("weapon_slot_%d"%i): cmd.weapon_slot = i
 cmd.respawn = Input.is_action_just_pressed("respawn")
 mouse_delta = Vector2.ZERO
 return touch.apply(cmd) if touch!=null else cmd

