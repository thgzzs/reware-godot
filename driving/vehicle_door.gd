class_name VehicleDoor
extends RigidBody3D
## A real Jolt hinge while unlatched; a latched door follows its chassis.
var car: DriveVehicle
var profile: VehicleDoorProfile
var side := 0
var hinge_offset := Vector3.ZERO
var joint: HingeJoint3D
var opened := false
var latched := true
var angle := 0.0
var panel: MeshInstance3D
func configure(owner_car: DriveVehicle, index: int) -> void:
	car = owner_car
	profile = car.door_profile
	side = index
	hinge_offset = profile.hinge_offsets[index]
	mass = profile.panel_mass
	freeze = true
	can_sleep = false
	collision_layer = 16
	collision_mask = 21
	continuous_cd = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = profile.panel_size
	shape.shape = box
	shape.position.z = box.size.z*0.5
	add_child(shape)
	panel = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	panel.mesh = mesh
	panel.position = shape.position
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c47555")
	panel.material_override = material
	add_child(panel)
	car.add_child(self)
	set_as_top_level(true)
	global_transform = car.global_transform*Transform3D(Basis.IDENTITY,hinge_offset)
	add_collision_exception_with(car)
	joint = HingeJoint3D.new()
	car.add_child(joint)
	joint.position = hinge_offset
	# HingeJoint3D rotates around its local Z. Map that axis to chassis Y.
	joint.rotation.x = -PI*0.5
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT,true)
	# The joint measures body A relative to B; our displayed angle is B in A.
	joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER,0.0 if side==0 else -deg_to_rad(profile.opening_degrees))
	joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER,deg_to_rad(profile.opening_degrees) if side==0 else 0.0)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE,profile.motor_impulse)
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR,true)
func request_open(value: bool) -> void:
	opened = value
	if value and latched:
		latched = false
		freeze = false
		joint.node_a = joint.get_path_to(car)
		joint.node_b = joint.get_path_to(self)
		linear_velocity = car.linear_velocity+car.angular_velocity.cross(global_position-car.global_position)
		angular_velocity = car.angular_velocity
func _physics_process(_dt: float) -> void:
	if not is_instance_valid(car): return
	if car.reset_pending: return
	if latched:
		global_transform = car.global_transform*Transform3D(Basis.IDENTITY,hinge_offset)
		angle = 0
		return
	var relative := car.global_basis.inverse()*global_basis
	angle = atan2(relative.z.x,relative.z.z)
	var target := (-1.0 if side==0 else 1.0)*deg_to_rad(profile.opening_degrees) if opened else 0.0
	joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY,clampf((angle-target)*profile.motor_gain,-3,3))
	if not opened and absf(angle)<profile.latch_radians and (angular_velocity-car.angular_velocity).length()<0.5:
		latched = true
		joint.node_a = NodePath("")
		joint.node_b = NodePath("")
		freeze = true
func attach_model(frame: Node3D) -> void:
	panel.hide()
	# Keep the source frame's model-space rest transform relative to its hinge.
	frame.reparent(self,true)
func reset_with_chassis(chassis: Transform3D) -> void:
	opened = false
	latched = true
	angle = 0
	joint.node_a = NodePath("")
	joint.node_b = NodePath("")
	freeze = true
	global_transform = chassis*Transform3D(Basis.IDENTITY,hinge_offset)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	PhysicsServer3D.body_set_state(get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,global_transform)
