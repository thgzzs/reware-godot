class_name AimSolution
extends RefCounted
## Camera reticle, skeletal aim and ballistics share this camera-center ray.
static func camera_target(space: PhysicsDirectSpaceState3D, camera: Camera3D, distance: float, exclude: Array[RID], forward_plane := Vector3.INF) -> Vector3:
 var end := camera.global_position-camera.global_basis.z*distance
 var from := camera.global_position
 if forward_plane.is_finite(): from += -camera.global_basis.z*maxf(0,(forward_plane-from).dot(-camera.global_basis.z))
 var hit := BallisticTrace.cast(space,from,end,exclude)
 return end if hit.is_empty() else hit.position
