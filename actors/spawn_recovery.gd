class_name ActorSpawnRecovery
extends Node
## Reuses actors and their shared motor; never replaces scene instances on death.
signal recovered(reason: String)
var profile: ActorSpawnProfile = preload("res://tuning/spawn.tres")
var actor: CharacterMotor
var transition: VehicleTransition
var brain: PedBrain
var automatic_death_respawn := false
var spawn_position := Vector3.ZERO
var spawn_heading := 0.0
var death_elapsed := 0.0
var retry_left := 0.0
var recoveries := 0
func _ready() -> void:
 spawn_position = actor.global_position
 spawn_heading = actor.facing
func _physics_process(dt: float) -> void:
 if not is_instance_valid(actor): return
 retry_left = maxf(0, retry_left-dt)
 var below_void := actor.global_position.y < profile.void_height
 if actor.reaction_body.active:
  below_void = below_void or actor.reaction_body.global_position.y < profile.void_height
 if actor.health.health<=0: death_elapsed += dt
 else: death_elapsed = 0
 if retry_left>0: return
 if below_void: recover("void")
 elif automatic_death_respawn and actor.health.health<=0 and death_elapsed>=profile.death_delay: recover("death")
func recover(reason: String) -> bool:
 var point := safe_spawn()
 if not point.is_finite():
  retry_left = profile.retry_seconds
  return false
 if is_instance_valid(transition): transition.abort_for_respawn()
 actor.facing = spawn_heading
 actor.respawn(point)
 if is_instance_valid(brain): brain.reset_decisions()
 death_elapsed = 0
 retry_left = 0
 recoveries += 1
 recovered.emit(reason)
 return true
func safe_spawn() -> Vector3:
 var query := PhysicsShapeQueryParameters3D.new()
 query.shape = actor.normal_shape
 query.collision_mask = 15
 query.exclude = [actor.get_rid(), actor.reaction_body.get_rid()]
 var space := actor.get_world_3d().direct_space_state
 # Try the original mark first, then small rings if a car/body blocks it.
 for ring in range(profile.clearance_rings+1):
  for sector in range(1 if ring==0 else 8):
   var angle := TAU*sector/8.0
   var candidate := spawn_position+Vector3(cos(angle),0,sin(angle))*ring*profile.clearance_radius
   var ray := PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*1.5,candidate-Vector3.UP*3,1,query.exclude)
   var floor_hit := space.intersect_ray(ray)
   if floor_hit.is_empty() or floor_hit.normal.y<actor.slope_cos(): continue
   candidate = floor_hit.position+Vector3.UP*0.94
   if absf(candidate.y-spawn_position.y)>profile.floor_height_tolerance: continue
   query.transform = Transform3D(Basis.IDENTITY,candidate)
   if space.intersect_shape(query,1).is_empty(): return candidate
 return Vector3.INF
