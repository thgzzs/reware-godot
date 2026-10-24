class_name BikeDynamics
extends RefCounted
## Grounded rider balance, walking reverse, physical falls and assisted pickup.
var profile:BikeProfile=preload("res://tuning/bike.tres")
var car:DriveVehicle
var lean:=0.0
var steering_nodes:Array[Node3D]=[]
var steering_rest:Array[Basis]=[]
var reverse_intent:=false
var lifting:=false
var mounting:=false
var lift_progress:=0.0
var crash_pending:DamageEvent
var last_crash_time:=-10.0
var clock:=0.0
var was_ridden:=false
func configure(vehicle:DriveVehicle) -> void:
 car=vehicle;car.kind="bike";car.active_contacts.assign([0,2])
 car.profile.wheel_radius=profile.wheel_radius;car.profile.suspension_length=profile.suspension_length;car.profile.static_sag=profile.static_sag
 car.profile.maximum_lateral_acceleration=profile.lateral_acceleration
 car.profile.spring_rate=car.mass*float(ProjectSettings.get_setting("physics/3d/default_gravity"))/(2*profile.static_sag)
 car.profile.damper=2*sqrt(car.profile.spring_rate*car.mass/2)*car.profile.damping_ratio
 car.profile.center_of_mass=Vector3(0,-0.25,0);car.center_of_mass=car.profile.center_of_mass
 for i in [1,3]:car.wheel_visuals[i].hide()
 for i in [0,2]:car.mounts[i].x=0
 for door in car.doors:door.joint.queue_free();door.queue_free()
 car.doors.clear();(car.get_node("Cab") as CollisionShape3D).disabled=true
 var hull:=car.get_node("Hull") as CollisionShape3D;hull.shape=hull.shape.duplicate();(hull.shape as BoxShape3D).size=Vector3(0.55,0.5,1.75);car.impact_probe.shape=hull.shape
 car.seating.configure(Vector3(0,0.2,0.15),Vector3(0,0.25,0.55));car.seating.definitions.remove_at(3);car.seating.definitions.remove_at(1)
 car.seating.definitions[1].id="bike_passenger";car.seating.definitions[1].approach=Vector3(1.2,0.2,0.5)
func fallen() -> bool:return car.global_basis.y.dot(Vector3.UP)<profile.pickup_up_dot
func record_collision(speed:float,normal:Vector3,velocity:Vector3,at:Vector3) -> void:
 if not is_instance_valid(car.driver)or lifting or clock-last_crash_time<1.0:return
 if speed<profile.crash_min_speed or absf(normal.dot(Vector3.UP))>0.75:return
 crash_pending=DamageEvent.make((speed-profile.crash_min_speed)*profile.crash_damage_scale,at,velocity,"vehicle",car)
 crash_pending.relative_speed=speed;crash_pending.normal=normal;last_crash_time=clock
 crash_pending.set_meta("launch_velocity",velocity)
func take_crash() -> DamageEvent:
 var event:=crash_pending;crash_pending=null;return event
func solve(state:PhysicsDirectBodyState3D) -> void:
 clock+=state.step
 if car.damage.state=="destroyed":return
 var supported:=car.wheels[0].touching or car.wheels[2].touching
 var ridden:=is_instance_valid(car.driver)
 if ridden and not was_ridden:crash_pending=null
 if not ridden and was_ridden:
  # A departing rider removes balance; a small roll starts an actual physical fall.
  state.angular_velocity+=state.transform.basis.z*0.45
 was_ridden=ridden
 if not ridden and not lifting and not mounting:return
 var up:=state.transform.basis.y
 if ridden and not lifting and (up.dot(Vector3.UP)<profile.fall_up_dot or state.angular_velocity.length()>profile.rider_max_angular_speed):
  record_collision(profile.crash_min_speed+1,Vector3.RIGHT,state.linear_velocity,state.transform.origin)
 if not supported and not lifting:return
 if up.dot(Vector3.UP)<profile.fall_up_dot and not lifting:return
 var forward:=-car.upright_basis().z
 var wheelbase:=maxf(0.7,absf(car.mounts[0].z-car.mounts[2].z))
 var gravity:=float(ProjectSettings.get_setting("physics/3d/default_gravity"))
 var requested:=atan(car.speed*car.speed*tan(car.steering)/(wheelbase*gravity))
 if absf(car.steering_input)<0.03 or reverse_intent or lifting or mounting:requested=0
 lean=move_toward(lean,clampf(requested,-profile.maximum_lean,profile.maximum_lean),state.step*profile.lean_return_rate)
 var desired_up:=Vector3.UP.rotated(forward,-lean)
 if lifting:desired_up=up.slerp(Vector3.UP,lift_progress).normalized()
 var rotation:=Quaternion(up.normalized(),desired_up)
 var error:=rotation.get_axis()*rotation.get_angle()
 var angular:=state.angular_velocity-Vector3.UP*state.angular_velocity.dot(Vector3.UP)
 var acceleration:=error*(profile.lift_strength if lifting else profile.balance_strength)-angular*(profile.lift_damping if lifting else profile.balance_damping)
 var inverse:=state.inverse_inertia_tensor
 if absf(inverse.determinant())>0.000000001:state.apply_torque(inverse.inverse()*acceleration.limit_length(45))
 if not lifting and absf(car.steering_input)<0.03:
  state.apply_torque(Vector3.UP*(-state.angular_velocity.y*car.mass*profile.coast_yaw_damping))
 if ridden and reverse_intent and car.throttle<0 and car.brake<0.5 and supported and not lifting:
  var reverse_force:=car.mass*profile.reverse_acceleration+car.profile.rolling_drag*2.0
  if car.speed> -profile.reverse_speed:state.apply_central_force(-forward*reverse_force)
  else:state.apply_central_force(forward*car.mass*(-car.speed-profile.reverse_speed)*6)
func update_visuals() -> void:
 for i in range(steering_nodes.size()):
  if is_instance_valid(steering_nodes[i]):steering_nodes[i].basis=Basis(Vector3.UP,car.steering)*steering_rest[i]
