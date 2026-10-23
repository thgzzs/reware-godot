class_name VehicleStability
extends RefCounted
## Ground-only anti-roll and angular damping, never an unconditional upright lock.
static func solve(car: DriveVehicle, state: PhysicsDirectBodyState3D) -> void:
 var contacts:=0
 for wheel in car.wheels:
  if wheel.touching:contacts+=1
 if contacts<2:return
 var up:=state.transform.basis.y
 var forward:=-state.transform.basis.z
 for axle in [[0,1],[2,3]]:
  var left:WheelForceSolver=car.wheels[axle[0]]
  var right:WheelForceSolver=car.wheels[axle[1]]
  if not left.touching or not right.touching:continue
  var force:=clampf((left.compression-right.compression)*car.profile.anti_roll_stiffness,-minf(left.normal_load,right.normal_load)*0.5,minf(left.normal_load,right.normal_load)*0.5)
  state.apply_force(up*force,state.transform.basis*car.mounts[axle[0]])
  state.apply_force(-up*force,state.transform.basis*car.mounts[axle[1]])
 state.apply_torque(-forward*state.angular_velocity.dot(forward)*car.mass*car.profile.roll_damping)
