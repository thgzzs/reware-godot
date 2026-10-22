class_name WeaponController
extends Node
signal shot_fired(origin: Vector3, end: Vector3, hit: bool)
signal recoil(amount: float)
@export var profile: WeaponProfile
var magazine := 0
var reserve := 0
var cooldown := 0.0
var reload_left := 0.0
var shots := 0
var last_hit := false
var rng := RandomNumberGenerator.new()
func _ready() -> void:
 magazine = profile.magazine_size
 reserve = profile.reserve_ammo
 rng.seed = 47821
func start_reload() -> void:
 if reload_left>0 or magazine>=profile.magazine_size or reserve<=0: return
 reload_left = profile.reload_seconds
func tick(cmd: GameplayCommand, active: bool, space: PhysicsDirectSpaceState3D, camera: Camera3D, muzzle: Vector3, exclude: Array[RID], dt: float) -> void:
 cooldown = maxf(0,cooldown-dt)
 if reload_left>0:
  reload_left = maxf(0,reload_left-dt)
  if reload_left <= 0:
   var transferred := mini(profile.magazine_size-magazine,reserve)
   magazine += transferred
   reserve -= transferred
 if not active: return
 if cmd.reload: start_reload()
 if not cmd.fire or reload_left>0 or cooldown>0.000001: return
 if magazine<=0:
  start_reload()
  return
 var direction := -camera.global_basis.z
 direction = direction.rotated(camera.global_basis.y,rng.randf_range(-profile.spread_radians,profile.spread_radians))
 direction = direction.rotated(camera.global_basis.x,rng.randf_range(-profile.spread_radians,profile.spread_radians))
 var aim_end := camera.global_position+direction*profile.range_meters
 var aim_query := PhysicsRayQueryParameters3D.create(camera.global_position,aim_end,13,exclude)
 var aim_hit := space.intersect_ray(aim_query)
 if not aim_hit.is_empty(): aim_end = aim_hit.position
 # Second ray prevents shooting through a wall between muzzle and crosshair.
 var query := PhysicsRayQueryParameters3D.create(muzzle,aim_end,13,exclude)
 var hit := space.intersect_ray(query)
 last_hit = not hit.is_empty()
 if last_hit:
  aim_end = hit.position
  if hit.collider.has_method("receive_damage"):
   hit.collider.receive_damage(profile.damage,hit.position,direction)
  if hit.collider is RigidBody3D:
   hit.collider.apply_impulse(direction*15.0,hit.position-hit.collider.global_position)
 magazine -= 1
 shots += 1
 cooldown = profile.interval
 if magazine == 0: start_reload()
 recoil.emit(profile.recoil_radians)
 shot_fired.emit(muzzle,aim_end,last_hit)
