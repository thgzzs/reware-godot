class_name BikeDynamics
extends RefCounted
## Two real tire contacts; rider-balanced roll response, separate from car anti-roll.
var profile:BikeProfile=preload("res://tuning/bike.tres")
var car:DriveVehicle
var lean:=0.0
var steering_nodes:Array[Node3D]=[]
var steering_rest:Array[Basis]=[]
func configure(vehicle:DriveVehicle) -> void:
 car=vehicle
 car.kind="bike"
 car.active_contacts.assign([0,2])
 car.profile.wheel_radius=profile.wheel_radius
 car.profile.suspension_length=profile.suspension_length
 car.profile.static_sag=profile.static_sag
 car.profile.maximum_lateral_acceleration=profile.lateral_acceleration
 car.profile.spring_rate=car.mass*float(ProjectSettings.get_setting("physics/3d/default_gravity"))/(2*profile.static_sag)
 car.profile.damper=2*sqrt(car.profile.spring_rate*car.mass/2)*car.profile.damping_ratio
 car.profile.center_of_mass=Vector3(0,-0.25,0)
 car.center_of_mass=car.profile.center_of_mass
 for i in [1,3]:car.wheel_visuals[i].hide()
 for i in [0,2]:car.mounts[i].x=0
 for door in car.doors:
  door.joint.queue_free()
  door.queue_free()
 car.doors.clear()
 (car.get_node("Cab") as CollisionShape3D).disabled=true
 var hull:=car.get_node("Hull") as CollisionShape3D
 hull.shape=hull.shape.duplicate()
 (hull.shape as BoxShape3D).size=Vector3(0.55,0.5,1.75)
 car.impact_probe.shape=hull.shape
 car.seating.configure(Vector3(0,0.2,0.15),Vector3(0,0.25,0.55))
 car.seating.definitions.remove_at(3)
 car.seating.definitions.remove_at(1)
 car.seating.definitions[1].id="bike_passenger"
 car.seating.definitions[1].approach=Vector3(1.2,0.2,0.5)
func solve(state:PhysicsDirectBodyState3D) -> void:
 if car.damage.state=="destroyed":return
 if not car.wheels[0].touching and not car.wheels[2].touching:return
 var up:=state.transform.basis.y
 if up.dot(Vector3.UP)<0.25:return
 var forward:=-state.transform.basis.z
 var wheelbase:=maxf(0.7,absf(car.mounts[0].z-car.mounts[2].z))
 var gravity:=float(ProjectSettings.get_setting("physics/3d/default_gravity"))
 var target:=atan(car.speed*car.speed*tan(car.steering)/(wheelbase*gravity))
 if not is_instance_valid(car.driver):target=profile.parked_lean
 lean=move_toward(lean,clampf(target,-profile.maximum_lean,profile.maximum_lean),state.step*2.5)
 var desired_up:=Vector3.UP.rotated(forward,-lean)
 var error:=up.cross(desired_up)
 var angular:=state.angular_velocity-Vector3.UP*state.angular_velocity.dot(Vector3.UP)
 var acceleration:=error*profile.balance_strength-angular*profile.balance_damping
 var inverse_inertia:=state.inverse_inertia_tensor
 if absf(inverse_inertia.determinant())>0.000000001:
  state.apply_torque(inverse_inertia.inverse()*acceleration)

func update_visuals() -> void:
 for i in range(steering_nodes.size()):
  if is_instance_valid(steering_nodes[i]):steering_nodes[i].basis=Basis(Vector3.UP,car.steering)*steering_rest[i]
