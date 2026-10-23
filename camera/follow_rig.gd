class_name FollowCameraRig
extends Node3D
@export var profile: CameraProfile
@onready var camera: Camera3D = $Camera3D
var yaw := 0.0
var pitch := 0.12
var initialized := false
var foot_mode := 1
var vehicle_mode := 1
var mode_name := "medium"
var vehicle_basis := Basis.IDENTITY
var vehicle_origin := Vector3.ZERO
var previous_vehicle_yaw := 0.0
var anchor := Vector3.ZERO
var arm_length := 5.5
var query := PhysicsShapeQueryParameters3D.new()
var obstruction_fraction := 1.0
func _ready() -> void:
 camera.keep_aspect = Camera3D.KEEP_HEIGHT
 var sphere := SphereShape3D.new()
 sphere.radius = profile.collision_radius
 query.shape = sphere
 query.collision_mask = 13
func read_look(cmd: GameplayCommand) -> void:
 yaw -= cmd.look.x*profile.mouse_sensitivity
 pitch = clampf(pitch+cmd.look.y*profile.mouse_sensitivity,profile.min_pitch,profile.max_pitch)
func tick(target: Vector3, cmd: GameplayCommand, driving: bool, exclude: Array[RID], dt: float) -> void:
 var weight := 1.0-exp(-profile.follow_rate*dt)
 if not initialized:
  anchor = target
  initialized = true
 anchor = anchor.lerp(target,weight)
 if driving and vehicle_mode==3: yaw += wrapf(vehicle_basis.get_euler().y-previous_vehicle_yaw,-PI,PI)
 previous_vehicle_yaw = vehicle_basis.get_euler().y
 if cmd.camera_cycle:
  if driving:
   vehicle_mode = (vehicle_mode+1)%4
   if vehicle_mode==3: yaw = vehicle_basis.get_euler().y
  else: foot_mode = (foot_mode+1)%3
 var distances := profile.vehicle_distances if driving else profile.on_foot_distances
 var index := mini(vehicle_mode,2) if driving else foot_mode
 var distance := float(distances[index])
 if cmd.aim and not driving: distance = profile.aim_distance
 mode_name = "bonnet" if driving and vehicle_mode==3 else ["near","medium","far"][index]
 arm_length = lerpf(arm_length,distance,weight)
 var basis_rotation := Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,-pitch)
 var shoulder := basis_rotation.x*profile.shoulder_offset if cmd.aim and not driving else Vector3.ZERO
 var desired := basis_rotation.z*arm_length+shoulder
 query.transform = Transform3D(Basis.IDENTITY,anchor)
 query.motion = desired
 query.exclude = exclude
 if driving and vehicle_mode==3:
  camera.global_position = vehicle_origin+vehicle_basis*profile.bonnet_camera_offset
  camera.global_basis = vehicle_basis*Basis(Vector3.UP,yaw-vehicle_basis.get_euler().y)*Basis(Vector3.RIGHT,-pitch)
  return
 var space := get_world_3d().direct_space_state
 var cast := space.cast_motion(query)
 obstruction_fraction = cast[0]
 # A swept sphere starts at the pivot; immediate retraction prevents wall clips.
 camera.global_position = anchor+desired*maxf(0.0,cast[0]-0.02)
 if camera.global_position.distance_to(anchor)>0.05:
  camera.look_at(anchor+shoulder)
 camera.fov = lerpf(camera.fov,profile.aim_fov if cmd.aim and not driving else profile.fov,weight)
func add_recoil(amount: float) -> void:
 pitch = clampf(pitch-amount,profile.min_pitch,profile.max_pitch)
