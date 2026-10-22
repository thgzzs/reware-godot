class_name FollowCameraRig
extends Node3D
@export var profile: CameraProfile
@onready var camera: Camera3D = $Camera3D
var yaw := 0.0
var pitch := 0.12
var initialized := false
var anchor := Vector3.ZERO
var arm_length := 5.5
var query := PhysicsShapeQueryParameters3D.new()
var obstruction_fraction := 1.0
func _ready() -> void:
 var sphere := SphereShape3D.new()
 sphere.radius = profile.collision_radius
 query.shape = sphere
 query.collision_mask = 13
func tick(target: Vector3, cmd: GameplayCommand, driving: bool, exclude: Array[RID], dt: float) -> void:
 yaw -= cmd.look.x*profile.mouse_sensitivity
 pitch = clampf(pitch+cmd.look.y*profile.mouse_sensitivity,profile.min_pitch,profile.max_pitch)
 var weight := 1.0-exp(-profile.follow_rate*dt)
 if not initialized:
  anchor = target
  initialized = true
 anchor = anchor.lerp(target,weight)
 var distance := profile.driving_distance if driving else (profile.aim_distance if cmd.aim else profile.follow_distance)
 arm_length = lerpf(arm_length,distance,weight)
 var basis_rotation := Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,-pitch)
 var shoulder := basis_rotation.x*profile.shoulder_offset if cmd.aim and not driving else Vector3.ZERO
 var desired := basis_rotation.z*arm_length+shoulder
 query.transform = Transform3D(Basis.IDENTITY,anchor)
 query.motion = desired
 query.exclude = exclude
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
