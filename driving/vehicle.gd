class_name DriveVehicle
extends RigidBody3D
@export var profile: HandlingProfile
var driver: Node = null
var reservation: Node = null
var throttle := 0.0
var brake := 1.0
var steering_input := 0.0
var steering := 0.0
var speed := 0.0
var wheels: Array[WheelForceSolver] = []
var mounts := [Vector3(-0.82,0.10,-1.25),Vector3(0.82,0.10,-1.25),Vector3(-0.82,0.10,1.25),Vector3(0.82,0.10,1.25)]
var wheel_visuals: Array[Node3D] = []
var force_telemetry := GameplayTelemetry.new()
var reset_pending := false
var reset_transform := Transform3D.IDENTITY
func _ready() -> void:
 mass = profile.mass
 center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
 center_of_mass = profile.center_of_mass
 continuous_cd = true
 can_sleep = false
 linear_damp = 0.02
 angular_damp = 0.25
 for i in range(4):
  wheels.append(WheelForceSolver.new())
  wheel_visuals.append(get_node("Wheel%d" % i))
func command(cmd: GameplayCommand) -> void:
 var pedal := -cmd.move.y
 throttle = pedal
 brake = 1.0 if cmd.brake else 0.0
 if pedal*speed < -0.5:
  brake = 1
  throttle = 0
 steering_input = -cmd.move.x
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
 var started_us := Time.get_ticks_usec()
 if reset_pending:
  state.transform = reset_transform
  state.linear_velocity = Vector3.ZERO
  state.angular_velocity = Vector3.ZERO
  reset_pending = false
 var forward := -state.transform.basis.z
 speed = state.linear_velocity.dot(forward)
 var limit := profile.steering_angle/(1.0+absf(speed)*profile.high_speed_steering)
 steering = move_toward(steering,steering_input*limit,profile.steering_rate*state.step)
 var drive_force := throttle*(profile.engine_force if throttle>=0 else profile.reverse_force)
 if (speed>profile.max_speed and drive_force>0) or (speed < -profile.max_reverse_speed and drive_force<0): drive_force = 0
 var driven_count := (2 if profile.driven_front else 0)+(2 if profile.driven_rear else 0)
 var space := get_world_3d().direct_space_state
 for i in range(4):
  var driven := profile.driven_front if i<2 else profile.driven_rear
  wheels[i].solve(state,space,mounts[i],steering if i<2 else 0.0,drive_force/maxi(1,driven_count) if driven else 0.0,brake*profile.brake_force/4.0,profile,get_rid())
 state.apply_central_force(-state.linear_velocity*state.linear_velocity.length()*profile.aero_drag)
 force_telemetry.record(Time.get_ticks_usec()-started_us)
func update_visuals(dt: float) -> void:
 for i in range(4):
  wheel_visuals[i].position = mounts[i]-Vector3.UP*(profile.suspension_length-wheels[i].compression)
  wheel_visuals[i].rotation.y = steering if i<2 else 0
  wheel_visuals[i].get_child(0).rotate_x(-speed*dt/profile.wheel_radius)
func reserve_seat(actor: Node) -> bool:
 if is_instance_valid(driver) or is_instance_valid(reservation): return false
 reservation = actor
 return true
func commit_seat(actor: Node) -> bool:
 if reservation != actor or is_instance_valid(driver): return false
 driver = actor
 reservation = null
 return true
func release_seat(actor: Node) -> void:
 if reservation == actor: reservation = null
 if driver == actor: driver = null
 throttle = 0
 steering_input = 0
 brake = 1
func park() -> void:
 throttle = 0
 steering_input = 0
 brake = 1
func reset_at(where: Vector3) -> void:
 reset_transform = Transform3D(Basis.IDENTITY,where)
 reset_pending = true
 park()
