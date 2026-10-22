class_name LocalInputSource
extends RefCounted
var mouse_delta := Vector2.ZERO
func install() -> void:
 var bindings := {"left":KEY_A,"right":KEY_D,"forward":KEY_W,"back":KEY_S,"jump":KEY_SPACE,"interact":KEY_E,"reload":KEY_R,"sprint":KEY_SHIFT,"walk":KEY_ALT,"brake":KEY_SPACE,"debug":KEY_F3}
 for action in bindings:
  if not InputMap.has_action(action):
   InputMap.add_action(action)
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
func sample() -> GameplayCommand:
 var cmd := GameplayCommand.new()
 cmd.move = Input.get_vector("left","right","forward","back")
 cmd.jump = Input.is_action_just_pressed("jump")
 cmd.interact = Input.is_action_just_pressed("interact")
 cmd.reload = Input.is_action_just_pressed("reload")
 cmd.aim = Input.is_action_pressed("aim")
 cmd.fire = Input.is_action_pressed("fire")
 cmd.walk = Input.is_action_pressed("walk")
 cmd.sprint = Input.is_action_pressed("sprint")
 cmd.brake = Input.is_action_pressed("brake")
 cmd.look = mouse_delta
 cmd.weapon_step = int(Input.is_action_just_pressed("weapon_next"))-int(Input.is_action_just_pressed("weapon_previous"))
 for i in range(9):
  if Input.is_action_just_pressed("weapon_slot_%d"%i): cmd.weapon_slot = i
 cmd.respawn = Input.is_action_just_pressed("respawn")
 mouse_delta = Vector2.ZERO
 return cmd

