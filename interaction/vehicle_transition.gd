class_name VehicleTransition
extends Node
signal state_changed(state_name: String)
@export var profile: InteractionProfile
var actor: CharacterMotor
var vehicle: DriveVehicle
var state := "on_foot"
var remaining := 0.0
var start_position := Vector3.ZERO
var exit_position := Vector3.ZERO
var message := ""
var elapsed := 0.0
var last_duration := 0.0
func request_enter(candidate: DriveVehicle) -> bool:
 if state != "on_foot" or not is_instance_valid(candidate): return false
 if not actor.grounded or actor.phase == "launch": return false
 if actor.global_position.distance_to(candidate.global_position)>profile.reach: return false
 if candidate.linear_velocity.length()>profile.max_transition_speed or candidate.global_basis.y.dot(Vector3.UP)<0.65: return false
 # Validate a short unobstructed line to the vehicle body before reserving.
 var q := PhysicsRayQueryParameters3D.create(actor.global_position,candidate.global_position,5,[actor.get_rid()])
 var hit := actor.get_world_3d().direct_space_state.intersect_ray(q)
 if not hit.is_empty() and hit.collider != candidate: return false
 if not candidate.reserve_seat(actor): return false
 vehicle = candidate
 vehicle.park()
 start_position = actor.global_position
 actor.ignore_vehicle_until_restored(vehicle)
 actor.set_embarked(true)
 remaining = profile.enter_seconds
 elapsed = 0
 change_state("entering")
 return true
func request_exit() -> bool:
 if state != "driving" or not is_instance_valid(vehicle): return false
 if vehicle.linear_velocity.length()>profile.max_transition_speed:
  message = "Stop the vehicle before exiting"
  return false
 var destination := find_exit()
 if destination.is_empty():
  message = "Exit blocked / clear a door"
  return false
 exit_position = destination.position
 remaining = profile.exit_seconds
 elapsed = 0
 vehicle.park()
 change_state("exiting")
 return true
func tick(dt: float) -> void:
 if state == "on_foot": return
 if not is_instance_valid(vehicle):
  recover()
  return
 if state == "driving":
  actor.global_position = vehicle.global_position
  return
 remaining = maxf(0,remaining-dt)
 elapsed += dt
 if state == "entering":
  if vehicle.linear_velocity.length()>profile.max_transition_speed*2:
   recover()
   return
  actor.global_position = start_position.lerp(vehicle.global_position,1.0-remaining/profile.enter_seconds)
  if remaining<=0:
   if vehicle.commit_seat(actor):
    last_duration = elapsed
    change_state("driving")
   else: recover()
 elif state == "exiting" and remaining<=0:
  # Re-evaluate the whole volume when committing: blockers may have moved.
  var destination := find_exit()
  if destination.is_empty():
   message = "Exit became blocked"
   change_state("driving")
   return
  actor.collision_grace = 0.1
  actor.reset_at(destination.position)
  actor.set_embarked(false)
  vehicle.release_seat(actor)
  vehicle = null
  last_duration = elapsed
  change_state("on_foot")
func find_exit() -> Dictionary:
 var space := actor.get_world_3d().direct_space_state
 for offset in profile.exit_offsets:
  var p: Vector3 = vehicle.global_transform*offset
  var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP,p-Vector3.UP*profile.floor_max_drop,13,[actor.get_rid(),vehicle.get_rid()])
  var hit := space.intersect_ray(ray)
  if hit.is_empty() or hit.normal.y<actor.slope_cos(): continue
  p = hit.position+Vector3.UP*0.93
  var query := PhysicsShapeQueryParameters3D.new()
  query.shape = actor.get_node("CollisionShape3D").shape
  query.transform = Transform3D(Basis.IDENTITY,p)
  query.collision_mask = 15
  query.exclude = [actor.get_rid()]
  query.margin = 0.01
  if space.intersect_shape(query,1).is_empty(): return {"position":p}
 return {}
func recover() -> void:
 if is_instance_valid(vehicle): vehicle.release_seat(actor)
 actor.reset_at(start_position)
 actor.collision_grace = 0.1
 actor.set_embarked(false)
 vehicle = null
 change_state("on_foot")
func change_state(next: String) -> void:
 state = next
 state_changed.emit(state)
func _exit_tree() -> void:
 if is_instance_valid(vehicle): vehicle.release_seat(actor)
