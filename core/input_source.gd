class_name LocalInputSource
extends RefCounted
var mouse_delta := Vector2.ZERO
func install() -> void:
 var bindings := {"left":KEY_A,"right":KEY_D,"forward":KEY_W,"back":KEY_S,"jump":KEY_SPACE,"interact":KEY_E,"reload":KEY_R,"sprint":KEY_SHIFT,"brake":KEY_SPACE,"debug":KEY_F3}
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
func sample() -> GameplayCommand:
 var cmd := GameplayCommand.new()
 cmd.move = Input.get_vector("left","right","forward","back")
 cmd.jump = Input.is_action_just_pressed("jump")
 cmd.interact = Input.is_action_just_pressed("interact")
 cmd.reload = Input.is_action_just_pressed("reload")
 cmd.aim = Input.is_action_pressed("aim")
 cmd.fire = Input.is_action_pressed("fire")
 cmd.sprint = Input.is_action_pressed("sprint")
 cmd.brake = Input.is_action_pressed("brake")
 cmd.look = mouse_delta
 mouse_delta = Vector2.ZERO
 return cmd
