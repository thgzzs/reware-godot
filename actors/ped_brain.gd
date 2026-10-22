class_name PedBrain
extends Node
## AI emits the same commands consumed by the player's CharacterMotor.
var actor: CharacterMotor
var player: CharacterMotor
var waypoints := PackedVector3Array()
var destination := 0
var state := "wander"
var threat := Vector3.ZERO
var flee_left := 0.0
var fear := 50.0
var temper := 50.0
var flee_distance := 17.0
var relationships := {}
func _physics_process(dt: float) -> void:
 if actor.health.health<=0:
  actor.tick(GameplayCommand.new(),0,dt)
  return
 var cmd := GameplayCommand.new()
 cmd.walk = true
 var target: Vector3 = waypoints[destination]
 if state=="flee":
  flee_left -= dt
  target = actor.global_position+(actor.global_position-threat).normalized()*8
  cmd.walk = false
  cmd.sprint = fear>=65
  if flee_left<=0: state = "wander"
 elif actor.global_position.distance_to(target)<0.8:
  destination = (destination+1)%waypoints.size()
 if state=="wander" and relationships.get("avoid",[]).has("PLAYER1") and actor.global_position.distance_to(player.global_position)<1.2:
  target = actor.global_position+(actor.global_position-player.global_position).normalized()*2
 var direction := (target-actor.global_position)
 direction.y = 0
 direction = direction.normalized()
 cmd.move = Vector2(direction.x,direction.z)
 actor.tick(cmd,0,dt)
func hear_shot(position: Vector3) -> void:
 if relationships.get("threat",[]).has("GUN") and actor.global_position.distance_to(position)<flee_distance:
  threat = position
  state = "flee"
  flee_left = 5.0
