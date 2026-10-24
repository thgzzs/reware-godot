class_name DriveVehicle
extends RigidBody3D
@export var profile: HandlingProfile
@export var door_profile: VehicleDoorProfile = preload("res://tuning/doors.tres")
var doors: Array[VehicleDoor] = []
var impact_probe: PedestrianImpactProbe
var seating := VehicleSeatMap.new()
var damage := VehicleDamage.new()
var parts := VehicleParts.new()
var bike: BikeDynamics
var kind := "car"
var bike_animation := "BIKEs"
var variant := VehicleVariant.new()
var entry_clips := {}
var entry_points := {}
var active_contacts:Array[int]=[0,1,2,3]
func wheel_indices() -> Array[int]:return active_contacts
var driver: Node:
 get: return seating.occupants.get(0)
var reservation: Node:
 get: return seating.reservations.get(0)
var control_owner := "parked"
var throttle := 0.0
var brake := 1.0
var steering_input := 0.0
var steering := 0.0
var speed := 0.0
var wheels: Array[WheelForceSolver] = []
var mounts := [Vector3(-0.82,0.10,-1.25),Vector3(0.82,0.10,-1.25),Vector3(-0.82,0.10,1.25),Vector3(0.82,0.10,1.25)]
var wheel_visuals: Array[Node3D] = []
var wheel_spinners: Array[Node3D] = []
var wheel_angles := PackedFloat32Array([0,0,0,0])
var force_telemetry := GameplayTelemetry.new()
var reset_pending := false
var reset_transform := Transform3D.IDENTITY
func _ready() -> void:
 door_profile = door_profile.duplicate()
 seating.configure(door_profile.seat_offset)
 parts.configure(self)
 damage.configure(self)
 add_child(damage)
 max_contacts_reported = 12
 contact_monitor = true
 mass = profile.mass
 center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
 center_of_mass = profile.center_of_mass
 continuous_cd = true
 can_sleep = false
 linear_damp = 0.02
 angular_damp = 0.25
 for i in range(4):
  wheels.append(WheelForceSolver.new())
  var wheel := get_node("Wheel%d" % i) as Node3D
  wheel_visuals.append(wheel)
  var spin := Node3D.new()
  spin.name = "AxleSpin"
  wheel.add_child(spin)
  for child in wheel.get_children():
   if child!=spin: child.reparent(spin,false)
  wheel_spinners.append(spin)
 for i in range(2):
  var door := VehicleDoor.new()
  door.configure(self,i)
  doors.append(door)
 impact_probe = PedestrianImpactProbe.new()
 impact_probe.configure(self)
 VehicleHitboxes.install(self)
 var presentation := VehicleDamageVisual.new()
 add_child(presentation)
 presentation.configure(self)
func _physics_process(dt: float) -> void:
 damage.tick(dt)
 if damage.state!="destroyed": impact_probe.sweep(dt)
 update_visuals(dt)
func set_door_open(side: int, value: bool) -> void:
 if side>=0 and side<doors.size(): doors[side].request_open(value)
func seat_position(index := 0) -> Vector3:
 return global_transform*seating.definitions[index].anchor
func approach_position(index := 0, side_override:=-1) -> Vector3:
 var local:Vector3=seating.definitions[index].approach
 if side_override>=0 and entry_points.has(Vector2i(index,side_override)):local=entry_points[Vector2i(index,side_override)]
 if side_override>=0:local.x=absf(local.x)*(-1 if side_override%2==0 else 1)
 var p := global_position+upright_basis()*local if kind=="bike" else global_transform*local
 var query := PhysicsRayQueryParameters3D.create(p+Vector3.UP*2,p-Vector3.UP*3,1,[get_rid()])
 var floor_hit := get_world_3d().direct_space_state.intersect_ray(query)
 if not floor_hit.is_empty() and floor_hit.normal.y>0.65: p.y = floor_hit.position.y+0.93
 return p
func upright_basis() -> Basis:
 var forward:=-global_basis.z;forward.y=0
 if forward.length_squared()<0.01:forward=Vector3.FORWARD
 return Basis.looking_at(forward.normalized(),Vector3.UP)
func command(cmd: GameplayCommand, owner_id := "external") -> void:
 control_owner = owner_id
 if damage.state=="destroyed":
  park()
  return
 var pedal := -cmd.move.y
 if bike!=null:bike.reverse_intent=pedal< -0.1
 throttle = pedal
 brake = 1.0 if cmd.brake else 0.0
 if pedal*speed < -0.5:
  brake = 1
  throttle = 0
 steering_input = -cmd.move.x
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
 var started_us := Time.get_ticks_usec()
 var was_reset := reset_pending
 if reset_pending:
  state.transform = reset_transform
  state.linear_velocity = Vector3.ZERO
  state.angular_velocity = Vector3.ZERO
  for door in doors: door.reset_with_chassis(state.transform)
  damage.previous_velocity = Vector3.ZERO
  damage.previous_angular = Vector3.ZERO
  damage.contacts.clear()
  reset_pending = false
 if not was_reset: damage.sample_contacts(state)
 var forward := -state.transform.basis.z
 speed = state.linear_velocity.dot(forward)
 var limit := profile.steering_angle/(1.0+absf(speed)*profile.high_speed_steering)
 var wheelbase: float=absf(mounts[0].z-mounts[2].z)
 limit=minf(limit,atan(profile.maximum_lateral_acceleration*wheelbase/maxf(1.0,speed*speed)))
 steering = move_toward(steering,steering_input*limit,profile.steering_rate*state.step)
 var drive_force := (0.0 if damage.state=="destroyed" else throttle)*(profile.engine_force if throttle>=0 else profile.reverse_force)
 if bike!=null and throttle<0:drive_force=0.0
 if (speed>profile.max_speed and drive_force>0) or (speed < -profile.max_reverse_speed and drive_force<0): drive_force = 0
 var boost:=lerpf(profile.launch_force_multiplier,1.0,clampf(absf(speed)/profile.launch_boost_end_speed,0,1))
 drive_force*=boost
 var indices:=wheel_indices()
 var axle_count:=1.0 if kind=="bike" else 2.0
 var driven_count := int(axle_count)*((1 if profile.driven_front else 0)+(1 if profile.driven_rear else 0))
 var space := get_world_3d().direct_space_state
 for i in indices:
  if bike!=null and not bike.use_wheel_support():
   wheels[i].touching=false;wheels[i].normal_load=0;wheels[i].compression=0;continue
  var driven := profile.driven_front if i<2 else profile.driven_rear
  wheels[i].solve(state,space,mounts[i],steering if i<2 else 0.0,drive_force/maxi(1,driven_count) if driven else 0.0,brake*profile.brake_force*(profile.brake_bias if i<2 else 1.0-profile.brake_bias)/axle_count,profile,get_rid(),damage.wheel_flat[i],damage.profile,indices.size())
 if kind=="bike" and bike!=null: bike.solve(state)
 elif kind=="car": VehicleStability.solve(self,state)
 state.apply_central_force(-state.linear_velocity*state.linear_velocity.length()*profile.aero_drag)
 force_telemetry.record(Time.get_ticks_usec()-started_us)
func update_visuals(dt: float) -> void:
 if bike!=null:bike.update_visuals()
 for i in range(4):
  wheel_visuals[i].position = mounts[i]-Vector3.UP*(profile.suspension_length-wheels[i].compression)
  wheel_visuals[i].rotation.y = steering if i<2 else 0
  var radius := profile.wheel_radius*(damage.profile.flat_radius_ratio if damage.wheel_flat[i] else 1.0)
  wheel_spinners[i].scale = Vector3.ONE
  var rolling_speed := wheels[i].rolling_speed if wheels[i].touching else speed
  wheel_angles[i] = wrapf(wheel_angles[i]-rolling_speed*dt/radius,-PI,PI)
  wheel_spinners[i].rotation.x = wheel_angles[i]
func reserve_seat(actor: Node, index := 0) -> bool:
 return damage.state!="destroyed" and seating.reserve(actor,index)
func commit_seat(actor: Node, index := 0) -> bool:
 return damage.state!="destroyed" and seating.commit(actor,index)
func release_seat(actor: Node,allow_stand:=true) -> void:
 var was_driver:=driver==actor
 seating.release(actor)
 if bike!=null and was_driver:bike.release_rider(allow_stand)
 if bike!=null and not is_instance_valid(driver):bike.mounting=false
 if not is_instance_valid(driver): park()
func receive_hit(event: DamageEvent) -> void: damage.receive_hit(event)
func coast() -> void:
 control_owner="coasting"
 throttle=0;steering_input=0;brake=0
func receive_damage(amount: float, point: Vector3, direction: Vector3) -> void:
 receive_hit(DamageEvent.make(amount,point,direction))
func park() -> void:
 control_owner = "parked"
 throttle = 0
 steering_input = 0
 brake = 1
func reset_at(where: Vector3) -> void:
 if bike!=null:bike.standing=true;bike.lean=0;bike.crash_pending=null
 reset_transform = Transform3D(Basis.IDENTITY,where)
 reset_pending = true
 park()

