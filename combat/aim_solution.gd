class_name AimSolution
extends RefCounted
## Camera reticle, skeletal aim and ballistics share this camera-center ray.
static func camera_target(space: PhysicsDirectSpaceState3D, camera: Camera3D, distance: float, exclude: Array[RID]) -> Vector3:
 var end := camera.global_position-camera.global_basis.z*distance
 var query := PhysicsRayQueryParameters3D.create(camera.global_position,end,13,exclude)
 var hit := space.intersect_ray(query)
 return end if hit.is_empty() else hit.position
