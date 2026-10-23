class_name BallisticTrace
extends RefCounted
## Car physics proxies are excluded; explicit component areas represent bullet geometry.
const MASK := 1|2|8|32
static func cast(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID]) -> Dictionary:
 var query := PhysicsRayQueryParameters3D.create(from,to,MASK,exclude)
 query.collide_with_areas = true
 return space.intersect_ray(query)
