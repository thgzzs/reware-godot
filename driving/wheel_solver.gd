class_name WheelForceSolver
extends RefCounted
## SI forces, relative point velocities, load-limited combined tire forces.
var compression := 0.0
var normal_load := 0.0
var slip := 0.0
var point := Vector3.ZERO
var touching := false
var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
func solve(state: PhysicsDirectBodyState3D, space: PhysicsDirectSpaceState3D, mount: Vector3, steer: float, drive: float, brake: float, cfg: HandlingProfile, body_rid: RID) -> void:
 var origin := state.transform*mount
 var up := state.transform.basis.y
 ray.from = origin
 ray.to = origin-up*(cfg.suspension_length+cfg.wheel_radius)
 ray.collision_mask = 13
 ray.exclude = [body_rid]
 var hit := space.intersect_ray(ray)
 touching = not hit.is_empty()
 normal_load = 0
 compression = 0
 slip = 0
 point = ray.to
 if not touching: return
 point = hit.position
 var normal: Vector3 = hit.normal
 if normal.dot(up)<0.2: return
 var lever := point-state.transform.origin
 var velocity := state.linear_velocity+state.angular_velocity.cross(lever-state.center_of_mass)
 if hit.collider is RigidBody3D:
  velocity -= hit.collider.linear_velocity+hit.collider.angular_velocity.cross(point-hit.collider.global_position)
 compression = clampf(cfg.suspension_length-(origin.distance_to(point)-cfg.wheel_radius),0,cfg.suspension_length)
 normal_load = clampf(compression*cfg.spring_rate-velocity.dot(normal)*cfg.damper,0,cfg.max_spring_force)
 var forward := (-state.transform.basis.z).rotated(up,steer).slide(normal).normalized()
 var side := forward.cross(normal).normalized()
 var longitudinal_speed := velocity.dot(forward)
 var lateral_speed := velocity.dot(side)
 var longitudinal := drive
 var stop_force := minf(absf(longitudinal_speed)*cfg.mass/(4.0*state.step),brake+cfg.rolling_drag)
 longitudinal -= signf(longitudinal_speed)*stop_force
 var lateral := -lateral_speed*cfg.lateral_stiffness
 var desired := Vector2(longitudinal,lateral)
 var limit := cfg.friction*normal_load
 slip = maxf(0,desired.length()-limit)
 desired = desired.limit_length(limit)
 var force := normal*normal_load+forward*desired.x+side*desired.y
 state.apply_force(force,lever)
 if hit.collider is RigidBody3D:
  hit.collider.apply_force(-force,point-hit.collider.global_position)
