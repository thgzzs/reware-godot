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
var seat_index := 0
var entry_side := 0
var auto_shuffle := false
var enter_total := 0.0
var enter_open := 0.0
var enter_close := 0.0
var exit_total := 0.0
var exit_close := 0.0
var escape_mode := false
var escape_clip := ""
var ejecting := false
var ejection_delay := 0.12
var seated_time := 0.0
var approach := VehicleApproach.new()
var lift_clip := ""
var lift_elapsed := 0.0
func clip_for(action_name:String, side:int) -> String:
 var suffix:="LHS" if side%2==0 else "RHS"
 if vehicle.kind=="bike":
  if action_name=="getin" and vehicle.entry_clips.has(side%2):return vehicle.entry_clips[side%2]
  var actions:={"getin":"_jumponL" if side%2==0 else "_jumponR","getout":"_getoffLHS" if side%2==0 else "_getoffRHS"}
  return vehicle.bike_animation+actions.get(action_name,"_Still")
 return "CAR_"+action_name+"_"+suffix

func request_enter(candidate: DriveVehicle, passenger_only := false) -> bool:
 message = ""
 if state!="on_foot" or not is_instance_valid(candidate) or not actor.control_enabled or actor.health.health<=0: return false
 if not actor.grounded or actor.phase!="grounded" or actor.actions.full_body_busy(): return false
 if actor.stance.crouched and not actor.stance.set_crouched(false): return false
 if candidate.damage.state=="destroyed": return false
 escape_mode=false;ejecting=false;seated_time=0
 var selected := candidate.seating.choose(candidate,actor.global_position,passenger_only)
 if candidate.kind=="bike" and not passenger_only and candidate.seating.available(0):selected=0
 var selected_side:=1 if (candidate.upright_basis().inverse()*(actor.global_position-candidate.global_position)).x>0 else 0
 if selected<0: return false
 if actor.global_position.distance_to(candidate.global_position)>profile.reach: return false
 if candidate.linear_velocity.length()>profile.max_transition_speed or (candidate.kind!="bike" and candidate.global_basis.y.dot(Vector3.UP)<0.65): return false
 var q := PhysicsRayQueryParameters3D.create(actor.global_position,candidate.global_position,5,[actor.get_rid()])
 var hit := actor.get_world_3d().direct_space_state.intersect_ray(q)
 if not hit.is_empty() and hit.collider!=candidate: return false
 var target:=candidate.approach_position(selected,selected_side if candidate.kind=="bike" else -1)
 var gap:=target-actor.global_position
 if Vector2(gap.x,gap.z).length()>profile.door_reach or absf(gap.y)>profile.maximum_entry_height:
  message="Move closer to the door or mount"
  return false
 if not approach.plan(actor,candidate,target,profile):
  message="Approach blocked / clear a route to the vehicle"
  return false
 if not candidate.reserve_seat(actor,selected): return false
 seat_index = selected
 entry_side = selected_side if candidate.kind=="bike" else candidate.seating.definitions[selected].door
 auto_shuffle = not passenger_only and selected==1 and candidate.kind!="bike"
 vehicle = candidate
 if not is_instance_valid(vehicle.driver):vehicle.park()
 start_position=actor.global_position
 change_state("approaching")
 return true
func begin_entry() -> void:
 start_position=actor.global_position
 var candidate:=vehicle
 if actor.reference_pose is SkinnedMotionVisual:
  var pose := actor.reference_pose as SkinnedMotionVisual
  var pelvis := pose.skeleton.find_bone("Pelvis")
  if pelvis>=0: standing_hip_offset = pose.skeleton.global_transform*pose.skeleton.get_bone_global_pose(pelvis).origin-actor.global_position
 actor.ignore_vehicle_until_restored(vehicle)
 actor.set_embarked(true)
 actor.visible = actor.reference_enabled
 enter_total = profile.enter_seconds
 enter_open = profile.enter_open_seconds
 enter_close = profile.enter_close_seconds
 if candidate.kind=="bike":
  enter_open=0;enter_close=0
  enter_total=maxf(0.5,actor.reference_motion.duration(clip_for("getin",entry_side))) if actor.reference_enabled else 0.8
 elif actor.reference_enabled and entry_side%2==1:
  enter_open = actor.reference_motion.duration("CAR_open_RHS")
  enter_close = actor.reference_motion.duration("CAR_closedoor_RHS")
  enter_total = enter_open+actor.reference_motion.duration("CAR_getin_RHS")+enter_close
 remaining = enter_total
 elapsed = 0
 vehicle.set_door_open(entry_side,not actor.reference_enabled)
 change_state("entering")
func approach_command() -> GameplayCommand:
 return approach.command()
func cancel_approach(reason: String) -> void:
 if is_instance_valid(vehicle):vehicle.release_seat(actor)
 vehicle=null
 message=reason
 change_state("on_foot")
func tick_approach(dt: float) -> void:
 if actor.health.health<=0 or not actor.control_enabled or not actor.grounded:
  cancel_approach("Entry interrupted")
  return
 if vehicle.damage.state=="destroyed" or vehicle.seating.reservations.get(seat_index)!=actor or vehicle.linear_velocity.length()>profile.max_transition_speed or (vehicle.kind!="bike" and vehicle.global_basis.y.dot(Vector3.UP)<0.65):
  cancel_approach("Vehicle or seat changed")
  return
 var target:=vehicle.approach_position(seat_index,entry_side if vehicle.kind=="bike" else -1)
 var arrived:=approach.advance(dt,target)
 if approach.elapsed>profile.approach_timeout or approach.stalled>profile.approach_stall_timeout:
  cancel_approach("Approach blocked / try another position")
  return
 if arrived:
  var desired:=vehicle.upright_basis().get_euler().y
  actor.facing=rotate_toward(actor.facing,desired,profile.approach_turn_rate*dt)
  actor.visual.rotation.y=actor.facing
  if absf(angle_difference(actor.facing,desired))<=profile.approach_heading_tolerance and Vector2(actor.velocity.x,actor.velocity.z).length()<0.25:
   if vehicle.kind=="bike" and vehicle.bike.fallen():begin_lift()
   else:begin_entry()
func request_exit() -> bool:
 message = ""
 if state not in ["driving","passenger"] or not is_instance_valid(vehicle): return false
 if vehicle.linear_velocity.length()>profile.max_transition_speed:
  return request_eject()
 escape_mode=vehicle.global_basis.y.dot(Vector3.UP)<0.65 or vehicle.kind=="bike"
 var destination := find_exit()
 if destination.is_empty():
  message = "Exit blocked / clear a door"
  return false
 exit_position = destination.position
 exit_side = destination.side
 exit_index = destination.index
 actor.visible = actor.reference_enabled
 exit_total = profile.exit_seconds
 exit_close = profile.exit_close_seconds
 if escape_mode:
  escape_clip=clip_for("getout",exit_side) if vehicle.kind=="bike" else "CAR_crawloutRHS"
  if vehicle.kind=="car" and actor.reference_pose!=null:actor.reference_pose.scale.x=-1.0 if exit_side%2==0 else 1.0
  exit_close=0
  exit_total=maxf(0.5,actor.reference_motion.duration(escape_clip)) if actor.reference_enabled else 0.8
 elif actor.reference_enabled and exit_side%2==1:
  exit_close = actor.reference_motion.duration("CAR_close_RHS")
  exit_total = actor.reference_motion.duration("CAR_getout_RHS")+exit_close
 remaining = exit_total
 elapsed = 0
 vehicle.park()
 vehicle.set_door_open(exit_side,not actor.reference_enabled)
 change_state("exiting")
 return true
func action(clip: String, time: float) -> void:
 if actor.reference_enabled:actor.reference_motion.vehicle_layers.clear()
 if not actor.reference_enabled: return
 actor.reference_motion.phase = state
 actor.reference_motion.set_clip(clip,false)
 actor.reference_motion.time = minf(time,actor.reference_motion.duration(clip))
 actor.facing = vehicle.upright_basis().get_euler().y
 actor.visual.rotation.y = actor.facing
func tick(dt: float) -> void:
 if state=="on_foot": return
 if not is_instance_valid(vehicle):
  if state=="approaching":cancel_approach("Vehicle removed");return
  recover()
  return
 if state=="approaching":
  tick_approach(dt)
  return
 if state=="lifting":
  tick_lift(dt)
  return
 if actor.health.health<=0:
  # Release ownership before the corpse resumes its own collision/reaction.
  vehicle.release_seat(actor)
  vehicle.set_door_open(0,false)
  vehicle.set_door_open(1,false)
  actor.global_position = vehicle.approach_position(seat_index,entry_side if vehicle.kind=="bike" else -1)
  actor.visible = true
  actor.set_reaction_shape()
  if actor.reference_pose!=null:actor.reference_pose.scale=Vector3.ONE
  vehicle = null
  change_state("on_foot")
  return
 if state=="ejecting":
  elapsed+=dt
  action(escape_clip,elapsed)
  align_to_seat()
  if elapsed>=ejection_delay:commit_eject()
  return
 if state in ["driving","passenger"]:
  if vehicle.bike!=null:
   var crash:=vehicle.bike.take_crash()
   if crash!=null:
    crash_eject(crash)
    return
  seated_time+=dt
  actor.visible = actor.reference_enabled
  if vehicle.kind=="bike":
   var pushing:bool=vehicle.bike.reverse_intent and vehicle.speed<0.25
   var base:=vehicle.bike_animation+("_pushes" if pushing else ("_Still" if absf(vehicle.speed)<0.35 else "_Ride")) if seat_index==0 else vehicle.bike_animation+"_passenger"
   action(base,fposmod(seated_time,maxf(0.001,actor.reference_motion.duration(base))) if actor.reference_enabled else 0)
   if actor.reference_enabled and seat_index==0:
    var lean:=clampf(absf(vehicle.bike.lean)/vehicle.bike.profile.maximum_lean,0,1)*0.7 if not pushing else 0.0
    var leaning:=vehicle.bike_animation+("_Left" if vehicle.bike.lean>0 else "_Right")
    actor.reference_motion.vehicle_layers=[{"clip":base,"time":actor.reference_motion.time,"weight":1.0-lean},{"clip":leaning,"time":minf(seated_time,actor.reference_motion.duration(leaning)),"weight":lean}]
  else:action(vehicle.seating.definitions[seat_index].seated_clip,0)
  if actor.reference_enabled: actor.reference_motion.phase = "seated"
  align_to_seat()
  return
 if state=="shuffling":
  remaining = maxf(0,remaining-dt)
  elapsed += dt
  action("CAR_shuffle_RHS",elapsed)
  align_pelvis(vehicle.seat_position(seat_index).lerp(vehicle.seat_position(0),smoothstep(0,shuffle_duration(),elapsed)))
  if remaining<=0:
   if vehicle.seating.transfer(actor,seat_index,0): seat_index=0;change_state("driving")
   else:
    if vehicle.seating.reservations.get(0)==actor:vehicle.seating.reservations.erase(0)
    message="Driver seat changed";change_state("passenger")
  return
 remaining = maxf(0,remaining-dt)
 elapsed += dt
 if state=="entering":
  var suffix := "LHS" if entry_side%2==0 else "RHS"
  if vehicle.linear_velocity.length()>profile.max_transition_speed*2:
   recover()
   return
  var getin_end := enter_total-enter_close
  if elapsed<enter_open:
   if elapsed>=profile.open_motion_start or not actor.reference_enabled: vehicle.set_door_open(entry_side,true)
   action("CAR_open_"+suffix,elapsed)
   actor.global_position = start_position.lerp(vehicle.approach_position(seat_index,entry_side if vehicle.kind=="bike" else -1),smoothstep(0,enter_open,elapsed))
  elif elapsed<getin_end:
   action(clip_for("getin",entry_side),elapsed-enter_open)
   actor.global_position = vehicle.approach_position(seat_index,entry_side if vehicle.kind=="bike" else -1)
   var mount_clip:=clip_for("getin",entry_side)
   if actor.reference_enabled:
    var end:=actor.reference_motion.position_at(mount_clip,actor.reference_motion.duration(mount_clip))
    var start:=actor.reference_motion.position_at(mount_clip,0)
    var at:=actor.reference_motion.position_at(mount_clip,elapsed-enter_open)
    var basis:=vehicle.upright_basis()
    var residual:=vehicle.approach_position(seat_index,entry_side if vehicle.kind=="bike" else -1)+standing_hip_offset-(vehicle.seat_position(seat_index)+basis*(start-end))
    var progress:=clampf((elapsed-enter_open)/maxf(0.001,getin_end-enter_open),0,1)
    align_pelvis(vehicle.seat_position(seat_index)+basis*(at-end)+residual*(1-progress))
   else:align_pelvis((vehicle.approach_position(seat_index,entry_side if vehicle.kind=="bike" else -1)+standing_hip_offset).lerp(vehicle.seat_position(seat_index),smoothstep(enter_open,getin_end,elapsed)))
  else:
   if elapsed-getin_end>=profile.entry_close_motion_start or not actor.reference_enabled: vehicle.set_door_open(entry_side,false)
   action("CAR_closedoor_"+suffix,elapsed-getin_end)
   align_to_seat()
  if remaining<=0:
   if vehicle.commit_seat(actor,seat_index):
    last_duration = elapsed
    change_state("driving" if vehicle.seating.definitions[seat_index].driver else "passenger")
    if auto_shuffle: request_switch_driver()
   else: recover()
 elif state=="exiting":
  if escape_mode:
   action(escape_clip,elapsed)
   var fraction:=elapsed/maxf(0.01,exit_total)
   var travel:=smoothstep(0,0.45,fraction) if vehicle.kind=="car" else smoothstep(0,1,fraction)
   var upright:=smoothstep(0,0.2,fraction) if vehicle.kind=="car" else smoothstep(0,1,fraction)
   actor.global_position=vehicle.seat_position(seat_index).lerp(exit_position,travel)
   if actor.reference_pose is SkinnedMotionVisual:
    actor.visual.global_basis=vehicle.global_basis.slerp(Basis(Vector3.UP,actor.facing),upright)
    align_pelvis(vehicle.seat_position(seat_index).lerp(exit_position+standing_hip_offset,travel),false)
   if remaining<=0:finish_exit()
   return
  var getout_end := exit_total-exit_close
  var suffix := "LHS" if exit_side%2==0 else "RHS"
  if elapsed<getout_end:
   if elapsed>=profile.exit_open_motion_start or not actor.reference_enabled: vehicle.set_door_open(exit_side,true)
   action(clip_for("getout",exit_side),elapsed)
   actor.global_position = vehicle.seat_position(seat_index)
   align_pelvis(vehicle.seat_position(seat_index).lerp(exit_position+standing_hip_offset,smoothstep(0,getout_end,elapsed)))
  else:
   if elapsed-getout_end>=profile.exit_close_motion_start or not actor.reference_enabled: vehicle.set_door_open(exit_side,false)
   action("CAR_close_"+suffix,elapsed-getout_end)
   actor.global_position = exit_position
  if remaining>0: return
  finish_exit()
func finish_exit() -> void:
 var destination:=find_exit(exit_index)
 if destination.is_empty():
  message="Exit became blocked"
  if actor.reference_pose!=null:actor.reference_pose.scale=Vector3.ONE
  change_state("driving" if vehicle.seating.definitions[seat_index].driver else "passenger")
  return
 actor.collision_grace=0.1
 actor.reset_at(destination.position)
 actor.set_embarked(false)
 vehicle.release_seat(actor)
 vehicle=null
 escape_mode=false
 last_duration=elapsed
 change_state("on_foot")
func request_eject() -> bool:
 var destination:=VehicleExitSolver.select(actor,vehicle,-1,seat_index,vehicle.kind=="bike")
 if destination.is_empty():message="No clear bailout path";return false
 exit_position=destination.position
 exit_side=destination.side;exit_index=destination.index
 escape_clip=vehicle.variant.bailout_clip(vehicle.bike_animation,actor.actions) if vehicle.kind=="bike" else ("CAR_rollout_LHS" if exit_side%2==0 else "CAR_rollout_RHS")
 ejection_delay=vehicle.variant.bike_bailout_release_seconds if vehicle.kind=="bike" else 0.12
 elapsed=0;ejecting=true;escape_mode=true
 actor.visible=actor.reference_enabled
 vehicle.set_door_open(exit_side,true)
 change_state("ejecting")
 return true
func commit_eject() -> void:
 var destination:=VehicleExitSolver.select(actor,vehicle,-1,seat_index,vehicle.kind=="bike")
 if destination.is_empty():
  message="Bailout path became blocked"
  ejecting=false;escape_mode=false
  change_state("driving" if vehicle.seating.definitions[seat_index].driver else "passenger")
  return
 var body:=vehicle
 var point:Vector3=destination.position
 exit_position=point
 var inherited:=body.linear_velocity+body.angular_velocity.cross(point-body.global_position)
 var outward:=point-body.global_position;outward.y=0;outward=outward.normalized()
 actor.reset_at(point)
 actor.set_embarked(false)
 actor.actions.begin_life("down")
 actor.actions.life_clip=escape_clip
 actor.actions.life_time=0
 actor.control_enabled=false
 actor.reaction_body.minimum_recovery_age=maxf(0.7,actor.reference_motion.duration(escape_clip)) if actor.reference_enabled else 0.7
 actor.reaction_body.launch_velocity(point,actor.facing,inherited+outward*1.5+Vector3.UP*2)
 body.release_seat(actor)
 if not is_instance_valid(body.driver):body.coast()
 vehicle=null;ejecting=false;escape_mode=false
 change_state("on_foot")

func align_to_seat() -> void:
 actor.global_position = vehicle.seat_position(seat_index)
 align_pelvis(vehicle.seat_position(seat_index))
func align_pelvis(anchor: Vector3, match_vehicle := true) -> void:
 if not actor.reference_pose is SkinnedMotionVisual: return
 var pose := actor.reference_pose as SkinnedMotionVisual
 if match_vehicle: actor.visual.global_basis = vehicle.global_basis
 pose.sample_pose(0)
 var pelvis := pose.skeleton.find_bone("Pelvis")
 if pelvis<0: pelvis = pose.skeleton.find_bone("Root")
 if pelvis>=0:
  var hip := pose.skeleton.global_transform*pose.skeleton.get_bone_global_pose(pelvis).origin
  actor.global_position += anchor-hip
func shuffle_duration() -> float:
 return maxf(0.1,actor.reference_motion.duration("CAR_shuffle_RHS")) if actor.reference_enabled else 0.65
func request_switch_driver() -> bool:
 if state!="passenger" or seat_index!=1 or not is_instance_valid(vehicle) or vehicle.kind=="bike": return false
 if vehicle.linear_velocity.length()>profile.max_transition_speed or vehicle.damage.state=="destroyed": return false
 if not vehicle.seating.reserve(actor,0,true):
  message = "Driver seat occupied"
  return false
 remaining = shuffle_duration()
 elapsed = 0
 change_state("shuffling")
 return true
func find_exit(required_index := -1) -> Dictionary:
 if escape_mode:return VehicleExitSolver.select(actor,vehicle,required_index,seat_index)
 var space := actor.get_world_3d().direct_space_state
 var order := range(profile.exit_offsets.size())
 if vehicle.seating.definitions[seat_index].door%2==1 and order.size()>1: order[0]=1;order[1]=0
 for i in order:
  var side := 0 if i!=1 else 1
  if side==vehicle.seating.definitions[seat_index].door%2: side=vehicle.seating.definitions[seat_index].door
  if required_index>=0 and required_index!=i: continue
  var offset: Vector3 = profile.exit_offsets[i]
  if seat_index>=2 and i<2: offset.z = vehicle.seating.definitions[seat_index].approach.z
  var p: Vector3 = vehicle.global_transform*offset
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
  route.transform = Transform3D(Basis.IDENTITY,vehicle.seat_position(seat_index))
  route.motion = p-vehicle.seat_position(seat_index)
  route.collision_mask = 15
  route.exclude = [actor.get_rid(),vehicle.get_rid()]
  var fractions := space.cast_motion(route)
  if fractions[0]<0.99: continue
  return {"position":p,"side":side,"index":i}
 return {}
func recover() -> void:
 if state=="lifting":cancel_lift("Bike lift cancelled");return
 if state=="approaching":cancel_approach("Entry cancelled");return
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
 if is_instance_valid(vehicle) and vehicle.bike!=null:vehicle.bike.mounting=next=="entering"
 actor.interaction_holstered = next!="on_foot"
 state = next
 state_changed.emit(state)
func _exit_tree() -> void:
 if is_instance_valid(vehicle) and vehicle.bike!=null:vehicle.bike.lifting=false;vehicle.bike.mounting=false
 if is_instance_valid(vehicle): vehicle.release_seat(actor)
func begin_lift() -> void:
 var side:="L" if entry_side%2==0 else "R"
 var pick:=vehicle.global_basis.x.dot(Vector3.UP)*(1 if entry_side%2==0 else -1)>0
 lift_clip=actor.actions.resolve(PackedStringArray(["BIKE_"+("pickup"if pick else "pullup")+side,"BIKE_pickup"+side]))
 lift_elapsed=0;vehicle.bike.lifting=true;vehicle.bike.lift_progress=0
 actor.control_enabled=false;actor.sprint.reset();actor.weapon.melee.cancel()
 change_state("lifting")
func tick_lift(dt:float) -> void:
 if actor.health.health<=0 or vehicle.damage.state=="destroyed" or vehicle.seating.reservations.get(seat_index)!=actor:
  cancel_lift("Bike lift interrupted");return
 lift_elapsed+=dt
 action(lift_clip,lift_elapsed)
 var length:=maxf(0.8,actor.reference_motion.duration(lift_clip)) if actor.reference_enabled else 1.0
 vehicle.bike.lift_progress=clampf((lift_elapsed-vehicle.bike.profile.lift_release_seconds)/maxf(0.2,length-vehicle.bike.profile.lift_release_seconds),0,1)
 if lift_elapsed>vehicle.bike.profile.lift_timeout:cancel_lift("Bike lift obstructed");return
 if lift_elapsed>=length and vehicle.global_basis.y.dot(Vector3.UP)>0.92 and vehicle.angular_velocity.length()<1.2:
  vehicle.bike.lifting=false;actor.restore_control()
  var target:=vehicle.approach_position(seat_index,entry_side)
  if not approach.plan(actor,vehicle,target,profile):cancel_lift("Mount path obstructed");return
  change_state("approaching")
func cancel_lift(reason:String) -> void:
 if is_instance_valid(vehicle) and vehicle.bike!=null:vehicle.bike.lifting=false
 if actor.health.health>0:actor.restore_control()
 cancel_approach(reason)
func crash_eject(event:DamageEvent) -> void:
 var point:=BikeEjectionSolver.destination(actor,vehicle)
 if not point.is_finite():message="Rider exit obstructed";return
 var body:=vehicle
 var initial:Vector3=event.get_meta("launch_velocity",body.linear_velocity)
 actor.facing=body.upright_basis().get_euler().y
 body.release_seat(actor);body.coast()
 actor.reset_at(point);actor.set_embarked(false)
 actor.health.receive(event.amount,false)
 if actor.health.health>0:actor.actions.begin_life("down")
 actor.actions.life_clip=actor.actions.resolve(PackedStringArray(["BIKE_fall_off","BIKE_fallR"]))
 actor.actions.life_time=0;actor.control_enabled=false
 actor.reaction_body.launch_velocity(point,actor.facing,initial*0.75+event.normal*1.5+Vector3.UP*2)
 actor.reaction_body.minimum_recovery_age=0.9
 vehicle=null;escape_mode=false;ejecting=false
 change_state("on_foot")
