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
var exit_side := 0
var exit_index := 0
var standing_hip_offset := Vector3.ZERO
func request_enter(candidate: DriveVehicle) -> bool:
 message = ""
 if state!="on_foot" or not is_instance_valid(candidate) or not actor.control_enabled or actor.health.health<=0: return false
 if not actor.grounded or actor.phase=="launch": return false
 if actor.global_position.distance_to(candidate.global_position)>profile.reach: return false
 if candidate.linear_velocity.length()>profile.max_transition_speed or candidate.global_basis.y.dot(Vector3.UP)<0.65: return false
 var q := PhysicsRayQueryParameters3D.create(actor.global_position,candidate.global_position,5,[actor.get_rid()])
 var hit := actor.get_world_3d().direct_space_state.intersect_ray(q)
 if not hit.is_empty() and hit.collider!=candidate: return false
 var approach := PhysicsShapeQueryParameters3D.new()
 approach.shape = actor.normal_shape
 approach.transform = actor.global_transform
 approach.transform.origin += Vector3.UP*0.03
 approach.motion = candidate.approach_position()-approach.transform.origin
 approach.margin = 0.001
 approach.collision_mask = 15
 approach.exclude = [actor.get_rid(),candidate.get_rid()]
 if actor.get_world_3d().direct_space_state.cast_motion(approach)[0]<0.99:
  message = "Approach blocked / clear the driver door"
  return false
 if not candidate.reserve_seat(actor): return false
 vehicle = candidate
 vehicle.park()
 start_position = actor.global_position
 if actor.reference_pose is SkinnedMotionVisual:
  var pose := actor.reference_pose as SkinnedMotionVisual
  var pelvis := pose.skeleton.find_bone("Pelvis")
  if pelvis>=0: standing_hip_offset = pose.skeleton.global_transform*pose.skeleton.get_bone_global_pose(pelvis).origin-actor.global_position
 actor.ignore_vehicle_until_restored(vehicle)
 actor.set_embarked(true)
 actor.visible = actor.reference_enabled
 remaining = profile.enter_seconds
 elapsed = 0
 vehicle.set_door_open(0,not actor.reference_enabled)
 change_state("entering")
 return true
func request_exit() -> bool:
 message = ""
 if state!="driving" or not is_instance_valid(vehicle): return false
 if vehicle.linear_velocity.length()>profile.max_transition_speed:
  message = "Stop the vehicle before exiting"
  return false
 var destination := find_exit()
 if destination.is_empty():
  message = "Exit blocked / clear a door"
  return false
 exit_position = destination.position
 exit_side = destination.side
 exit_index = destination.index
 actor.visible = actor.reference_enabled
 remaining = profile.exit_seconds
 elapsed = 0
 vehicle.park()
 vehicle.set_door_open(exit_side,not actor.reference_enabled)
 change_state("exiting")
 return true
func action(clip: String, time: float) -> void:
 if not actor.reference_enabled: return
 actor.reference_motion.phase = state
 actor.reference_motion.set_clip(clip,false)
 actor.reference_motion.time = minf(time,actor.reference_motion.duration(clip))
 actor.facing = vehicle.global_rotation.y
 actor.visual.rotation.y = actor.facing
func tick(dt: float) -> void:
 if state=="on_foot": return
 if not is_instance_valid(vehicle):
  recover()
  return
 if actor.health.health<=0:
  # Release ownership before the corpse resumes its own collision/reaction.
  vehicle.release_seat(actor)
  vehicle.set_door_open(0,false)
  vehicle.set_door_open(1,false)
  actor.global_position = vehicle.approach_position()
  actor.visible = true
  actor.set_reaction_shape()
  vehicle = null
  change_state("on_foot")
  return
 if state=="driving":
  actor.visible = actor.reference_enabled
  action("CAR_sit",0)
  if actor.reference_enabled: actor.reference_motion.phase = "seated"
  align_to_seat()
  return
 remaining = maxf(0,remaining-dt)
 elapsed += dt
 if state=="entering":
  if vehicle.linear_velocity.length()>profile.max_transition_speed*2:
   recover()
   return
  var getin_end := profile.enter_seconds-profile.enter_close_seconds
  if elapsed<profile.enter_open_seconds:
   if elapsed>=profile.open_motion_start or not actor.reference_enabled: vehicle.set_door_open(0,true)
   action("CAR_open_LHS",elapsed)
   actor.global_position = start_position.lerp(vehicle.approach_position(),smoothstep(0,profile.enter_open_seconds,elapsed))
  elif elapsed<getin_end:
   action("CAR_getin_LHS",elapsed-profile.enter_open_seconds)
   actor.global_position = vehicle.approach_position()
   align_pelvis((vehicle.approach_position()+standing_hip_offset).lerp(vehicle.seat_position(),smoothstep(profile.enter_open_seconds,getin_end,elapsed)))
  else:
   if elapsed-getin_end>=profile.entry_close_motion_start or not actor.reference_enabled: vehicle.set_door_open(0,false)
   action("CAR_closedoor_LHS",elapsed-getin_end)
   align_to_seat()
  if remaining<=0:
   if vehicle.commit_seat(actor):
    last_duration = elapsed
    change_state("driving")
   else: recover()
 elif state=="exiting":
  var getout_end := profile.exit_seconds-profile.exit_close_seconds
  var suffix := "LHS" if exit_side==0 else "RHS"
  if elapsed<getout_end:
   if elapsed>=profile.exit_open_motion_start or not actor.reference_enabled: vehicle.set_door_open(exit_side,true)
   action("CAR_getout_"+suffix,elapsed)
   actor.global_position = vehicle.seat_position()
   align_pelvis(vehicle.seat_position().lerp(exit_position+standing_hip_offset,smoothstep(0,getout_end,elapsed)))
  else:
   if elapsed-getout_end>=profile.exit_close_motion_start or not actor.reference_enabled: vehicle.set_door_open(exit_side,false)
   action("CAR_close_"+suffix,elapsed-getout_end)
   actor.global_position = exit_position
  if remaining>0: return
  # Revalidate the selected volume: never teleport to another newly clear door.
  var destination := find_exit(exit_index)
  if destination.is_empty():
   message = "Exit became blocked"
   actor.visible = false
   change_state("driving")
   return
  actor.collision_grace = 0.1
  actor.reset_at(destination.position)
  actor.set_embarked(false)
  vehicle.release_seat(actor)
  vehicle = null
  last_duration = elapsed
  change_state("on_foot")
func align_to_seat() -> void:
 actor.global_position = vehicle.seat_position()
 align_pelvis(vehicle.seat_position())
func align_pelvis(anchor: Vector3) -> void:
 if not actor.reference_pose is SkinnedMotionVisual: return
 var pose := actor.reference_pose as SkinnedMotionVisual
 actor.visual.global_basis = vehicle.global_basis
 pose.sample_pose(0)
 var pelvis := pose.skeleton.find_bone("Pelvis")
 if pelvis<0: pelvis = pose.skeleton.find_bone("Root")
 if pelvis>=0:
  var hip := pose.skeleton.global_transform*pose.skeleton.get_bone_global_pose(pelvis).origin
  actor.global_position += anchor-hip
func find_exit(required_index := -1) -> Dictionary:
 var space := actor.get_world_3d().direct_space_state
 for i in range(profile.exit_offsets.size()):
  var side := 0 if i!=1 else 1
  if required_index>=0 and required_index!=i: continue
  var p: Vector3 = vehicle.global_transform*profile.exit_offsets[i]
  var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP,p-Vector3.UP*profile.floor_max_drop,13,[actor.get_rid(),vehicle.get_rid()])
  var hit := space.intersect_ray(ray)
  if hit.is_empty() or hit.normal.y<actor.slope_cos(): continue
  p = hit.position+Vector3.UP*0.93
  var query := PhysicsShapeQueryParameters3D.new()
  query.shape = actor.normal_shape
  query.transform = Transform3D(Basis.IDENTITY,p)
  query.collision_mask = 15
  query.exclude = [actor.get_rid()]
  query.margin = 0.01
  if not space.intersect_shape(query,1).is_empty(): continue
  # Check the route as well as the destination; the chassis itself is excluded.
  var route := PhysicsShapeQueryParameters3D.new()
  route.shape = actor.normal_shape
  route.transform = Transform3D(Basis.IDENTITY,vehicle.seat_position())
  route.motion = p-vehicle.seat_position()
  route.collision_mask = 15
  route.exclude = [actor.get_rid(),vehicle.get_rid()]
  var fractions := space.cast_motion(route)
  if fractions[0]<0.99: continue
  return {"position":p,"side":side,"index":i}
 return {}
func recover() -> void:
 if is_instance_valid(vehicle):
  vehicle.release_seat(actor)
  vehicle.set_door_open(0,false)
  vehicle.set_door_open(1,false)
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
