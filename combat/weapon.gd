class_name WeaponController
extends Node
signal shot_fired(origin: Vector3, end: Vector3, hit: bool)
signal recoil(amount: float)
signal equipped(profile: WeaponProfile)
@export var profile: WeaponProfile
@export var loadout: WeaponLoadout = preload("res://tuning/arsenal.tres")
var actor: CharacterMotor
var melee := MeleeController.new()
var trigger_allowed := true
var magazine := 0
var reserve := 0
var cooldown := 0.0
var reload_left := 0.0
var shots := 0
var last_hit := false
var rng := RandomNumberGenerator.new()
var inventory: Array[Dictionary] = []
var active_slot := 0
var equip_action:=WeaponEquipState.new()
func _ready() -> void:
 melee.configure(actor)
 magazine = profile.magazine_size
 reserve = profile.reserve_ammo
 rng.seed = 47821
 var profiles: Array[WeaponProfile] = loadout.profiles.duplicate()
 if profiles.is_empty(): profiles.append(profile)
 else: profiles[0] = profile
 configure_loadout(profiles)
func configure_loadout(profiles: Array[WeaponProfile]) -> void:
 equip_action.reset()
 inventory.clear()
 for item in profiles:
  inventory.append({"profile":item,"magazine":item.magazine_size,"reserve":item.reserve_ammo})
 active_slot = -1
 equip_slot(0)
func equip_slot(index: int) -> bool:
 if index<0 or index>=inventory.size() or index==active_slot: return false
 equip_action.reset()
 if active_slot>=0:
  inventory[active_slot].magazine = magazine
  inventory[active_slot].reserve = reserve
 melee.cancel()
 active_slot = index
 profile = inventory[index].profile
 magazine = inventory[index].magazine
 reserve = inventory[index].reserve
 reload_left = 0
 # Switching cannot bypass an outstanding shot cooldown.
 equipped.emit(profile)
 return true
func request_equip(index:int) -> bool:
 if index<0 or index>=inventory.size() or index==active_slot or equip_action.busy():return false
 if actor==null or not actor.reference_enabled:return equip_slot(index)
 if actor.actions.life!="alive" or not actor.control_enabled:return false
 equip_action.lower_seconds=actor.actions.profile.weapon_lower_seconds
 equip_action.raise_seconds=actor.actions.profile.weapon_raise_seconds
 equip_action.begin(index,profile)
 melee.cancel();reload_left=0
 actor.actions.firing_left=0
 return true
func select(cmd: GameplayCommand) -> void:
 if cmd.weapon_slot>=0: request_equip(cmd.weapon_slot)
 elif cmd.weapon_step!=0 and not inventory.is_empty(): request_equip(posmod(active_slot+cmd.weapon_step,inventory.size()))
func advance_equip(dt:float) -> void:
 if not equip_action.busy():return
 if profile!=equip_action.source:
  equip_action.reset();return
 equip_action.elapsed+=dt
 if equip_action.phase=="lowering" and equip_action.elapsed>=equip_action.lower_seconds:
  var target:=equip_action.slot
  if equip_slot(target):
   equip_action.phase="raising";equip_action.source=profile;equip_action.elapsed=0
 elif equip_action.phase=="raising" and equip_action.elapsed>=equip_action.raise_seconds:
  equip_action.reset()
func start_reload() -> void:
 if profile.kind=="melee": return
 if equip_action.busy() or reload_left>0 or magazine>=profile.magazine_size or reserve<=0: return
 reload_left = profile.reload_seconds
func tick(cmd: GameplayCommand, active: bool, space: PhysicsDirectSpaceState3D, camera: Camera3D, muzzle: Vector3, exclude: Array[RID], dt: float) -> void:
 advance(cmd,active,dt)
 if active: try_fire(cmd,space,camera,muzzle,exclude)
func advance(cmd: GameplayCommand, active: bool, dt: float) -> void:
 cooldown = maxf(0,cooldown-dt)
 if not active:
  equip_action.reset();melee.cancel();reload_left=0
  return
 advance_equip(dt)
 select(cmd)
 if equip_action.busy():
  melee.cancel();reload_left=0
  return
 if actor!=null:melee.tick(cmd,dt)
 if actor!=null and (not actor.grounded or actor.phase!="grounded" or cmd.jump): reload_left = 0
 if reload_left>0:
  reload_left = maxf(0,reload_left-dt)
  if reload_left <= 0:
   var transferred := mini(profile.magazine_size-magazine,reserve)
   magazine += transferred
   reserve -= transferred
 if cmd.reload and (actor==null or actor.can_use_weapon()): start_reload()
func try_fire(cmd: GameplayCommand, space: PhysicsDirectSpaceState3D, camera: Camera3D, muzzle: Vector3, exclude: Array[RID]) -> void:
 if not cmd.fire or not trigger_allowed or equip_action.busy(): return
 if actor!=null and not actor.can_use_weapon(): return
 if profile.kind=="melee":
  if cooldown>0.000001: return
  melee.damage = profile.damage
  if melee.request(cmd): cooldown=profile.interval
  return
 if reload_left>0 or cooldown>0.000001: return
 if actor!=null:
  var target := AimSolution.camera_target(space,camera,profile.range_meters,exclude)
  var toward := -camera.global_basis.z
  var forward := Basis(Vector3.UP,actor.facing)*Vector3.FORWARD
  if forward.dot(Vector3(toward.x,0,toward.z).normalized())<cos(1.1 if cmd.aim or profile.two_handed else 1.65): return
 if magazine<=0:
  start_reload()
  return
 for pellet in range(profile.pellets): fire_ray(space,camera,muzzle,exclude)
 magazine -= 1
 shots += 1
 cooldown = profile.interval
 if magazine == 0: start_reload()
 recoil.emit(profile.recoil_radians)
func fire_ray(space: PhysicsDirectSpaceState3D, camera: Camera3D, muzzle: Vector3, exclude: Array[RID]) -> void:
 var direction := -camera.global_basis.z
 direction = direction.rotated(camera.global_basis.y,rng.randf_range(-profile.spread_radians,profile.spread_radians))
 direction = direction.rotated(camera.global_basis.x,rng.randf_range(-profile.spread_radians,profile.spread_radians))
 var aim_end := camera.global_position+direction*profile.range_meters
 var from := camera.global_position+direction*maxf(0,(muzzle-camera.global_position).dot(direction))
 var aim_hit := BallisticTrace.cast(space,from,aim_end,exclude)
 if not aim_hit.is_empty(): aim_end = aim_hit.position
 if actor!=null:
  var shoulder := actor.global_position+Vector3.UP*(-0.15 if actor.stance.crouched else 0.35)
  var cover := BallisticTrace.cast(space,shoulder,muzzle,exclude)
  if not cover.is_empty(): muzzle = cover.position-(muzzle-shoulder).normalized()*0.01
 # Second ray prevents shooting through a wall between muzzle and crosshair.
 var hit := BallisticTrace.cast(space,muzzle,aim_end,exclude)
 last_hit = not hit.is_empty()
 if last_hit:
  aim_end = hit.position
  var event := DamageEvent.make(profile.damage,hit.position,(aim_end-muzzle).normalized(),"bullet",actor)
  event.normal = hit.normal
  DamageEvent.deliver(hit.collider,event)
  if hit.collider is RigidBody3D and not hit.collider.has_method("receive_hit"):
   hit.collider.apply_impulse((aim_end-muzzle).normalized()*15.0,hit.position-hit.collider.global_position)
 shot_fired.emit(muzzle,aim_end,last_hit)

