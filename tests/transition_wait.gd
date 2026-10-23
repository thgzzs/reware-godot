class_name TransitionTestWait
extends RefCounted
## Separate automatic approach time from animation-stage timing assertions.
static func approach(arena: Node3D, maximum_ticks := 600) -> bool:
 for i in range(maximum_ticks):
  if arena.transition.state!="approaching":return true
  arena.injected_command=GameplayCommand.new()
  await arena.get_tree().physics_frame
  await arena.get_tree().process_frame
 return false
