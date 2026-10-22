class_name CharacterMotor
extends CharacterBody3D
## CharacterBody supplies swept collision only; acceleration, support, steps,
## sliding, launch and landing policy belong to this component.
@export var profile: MovementProfile
@onready var visual: Node3D = $Visual
var reference_motion: ReferenceMotion
var weapon: WeaponController
var weapon_muzzle: Node3D
var health: PedHealth
var archetype := "STAT_PLAYER"
var reference_enabled := false
var attack_multiplier := 1.0
var reference_pose: Node3D
var actions := ActorActionState.new()
var reaction_velocity := Vector3.ZERO
var impact_cooldown := 0.0
var down_time := 0.0
var normal_shape: Shape3D
var low_shape := SphereShape3D.new()
var grounded := false
var support_normal := Vector3.UP
var phase := "airborne"
var control_enabled := true
var jump_left := 0.0
var grace_left := 0.0
var phase_left := 0.0
var last_impact_speed := 0.0
var last_step := 0.0
var last_normal := Vector3.ZERO
var facing := 0.0
var drive_velocity := Vector3.ZERO
var jump_count := 0
var landing_count := 0
var ignored_vehicle: PhysicsBody3D
var collision_grace := 0.0
func _ready() -> void:
 weapon = WeaponController.new()
 weapon.profile = preload("res://tuning/weapon.tres")
 add_child(weapon)
 health = PedHealth.new()
 add_child(health)
 normal_shape = $CollisionShape3D.shape
 low_shape.radius = 0.32
 health.depleted.connect(func():
  control_enabled = false
  actions.begin_life("dying")
  set_reaction_shape())
 weapon.shot_fired.connect(func(_a: Vector3,_b: Vector3,_hit: bool): actions.fire(weapon.profile.interval))
func configure_reference(db: ImportedGameplayDatabase, stat: String, library: AnimationLibrary) -> void:
 archetype = stat
 var record := db.find_record("ped_stats",stat)
 profile = profile.duplicate()
 if not record.is_empty():
  # Source heading rates use normalized ticks (50/s), not degrees/second.
  profile.turn_rate = deg_to_rad(record.heading_rate_per_normalized_tick*50.0)
  health.defense_multiplier = record.defense_multiplier
  attack_multiplier = record.attack_multiplier
 reference_motion = ReferenceMotion.new(library)
 actions.motion = reference_motion
 if stat!="STAT_PLAYER":
  reference_motion.walk_clip = "WOMAN_walknorm" if "GIRL" in stat else "WALK_civi"
  reference_motion.run_clip = "woman_run" if "GIRL" in stat else "run_civi"
 profile.launch_delay = reference_motion.duration("JUMP_launch")
 profile.landing_delay = reference_motion.duration("JUMP_land")
 profile.jump_buffer = 0.001
 profile.coyote_time = 0.001
 profile.air_acceleration = 0.0
 collision_layer = 10
 collision_mask = 15
 reference_enabled = true
 for child in visual.get_children(): child.visible = false
 reference_pose = ReferencePose.new()
 reference_pose.motion = reference_motion
 visual.add_child(reference_pose)
func receive_damage(amount: float, _point: Vector3, _direction: Vector3) -> void:
 reaction_velocity += _direction.normalized()*minf(2.0,amount*0.02)
 health.receive(amount)
func set_reaction_shape() -> void:
 collision_layer = 8 if health.health>0 else 0
 collision_mask = 1
 $CollisionShape3D.set_deferred("shape",low_shape)
 $CollisionShape3D.set_deferred("position",Vector3(0,-0.58,0))
func receive_vehicle_impact(car: DriveVehicle, closing_speed: float, direction: Vector3) -> void:
 if impact_cooldown>0 or health.health<=0 or not visible or closing_speed<actions.profile.impact_min_speed: return
 impact_cooldown = actions.profile.impact_cooldown_seconds
 reaction_velocity = direction.normalized()*minf(closing_speed*0.65,9.0)+Vector3.UP*minf(closing_speed*0.10,1.5)
 health.receive(pow(maxf(0,closing_speed-actions.profile.impact_min_speed),2)*actions.profile.impact_damage_coefficient)
 if health.health>0: actions.begin_life("down")
 down_time = 0
 control_enabled = false
 set_reaction_shape()
 ignore_vehicle_until_restored(car)
func tick_reaction(dt: float) -> void:
 down_time += dt
 actions.tick(GameplayCommand.new(),weapon,dt)
 reaction_velocity.x = move_toward(reaction_velocity.x,0,4.0*dt)
 reaction_velocity.z = move_toward(reaction_velocity.z,0,4.0*dt)
 reaction_velocity.y -= profile.gravity*dt
 grounded = false
 var hit := move_and_collide(reaction_velocity*dt,false,0.002)
 if hit!=null:
  reaction_velocity = reaction_velocity.slide(hit.get_normal())
  grounded = hit.get_normal().y>=slope_cos()
 velocity = reaction_velocity
 if health.health<=0: return
 if actions.life=="down" and down_time>actions.profile.knockdown_seconds+maxf(0.1,reference_motion.duration(actions.life_clip) if reference_enabled else 0.6):
  var query := PhysicsShapeQueryParameters3D.new()
  query.shape = normal_shape
  query.transform = global_transform
  query.collision_mask = 15
  query.exclude = [get_rid()]
  if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
   actions.life = "getting_up"
   actions.life_time = 0
   actions.life_clip = actions.resolve(actions.profile.getup_clips)
 if actions.life=="getting_up" and actions.life_time>=maxf(0.5,reference_motion.duration(actions.life_clip) if reference_enabled else 0.5):
  restore_control()
func restore_control() -> void:
 actions.reset()
 control_enabled = true
 collision_layer = 10 if reference_enabled else 2
 collision_mask = 15 if reference_enabled else 13
 $CollisionShape3D.shape = normal_shape
 $CollisionShape3D.position = Vector3.ZERO
 reaction_velocity = Vector3.ZERO
 if reference_enabled:
  reference_motion.phase = "idle"
  reference_motion.set_clip("IDLE_stance")
func respawn(where: Vector3) -> void:
 health.reset()
 restore_control()
 reset_at(where)
func tick(cmd: GameplayCommand, camera_yaw: float, dt: float) -> void:
 impact_cooldown = maxf(0,impact_cooldown-dt)
 if is_instance_valid(ignored_vehicle):
  collision_grace -= dt
  if collision_grace<=0 and actions.life=="alive":
   remove_collision_exception_with(ignored_vehicle)
   ignored_vehicle = null
 if actions.life!="alive":
  tick_reaction(dt)
  return
 actions.tick(cmd,weapon,dt)
 if not control_enabled:
  if reference_enabled:
   if reference_motion.phase=="seated": reference_motion.force_action("CAR_sit",dt)
  velocity = Vector3.ZERO
  return
 last_step = 0.0
 jump_left = maxf(0.0,jump_left-dt)
 grace_left = profile.coyote_time if grounded else maxf(0.0,grace_left-dt)
 if cmd.jump: jump_left = profile.jump_buffer
 phase_left = maxf(0.0,phase_left-dt)
 if phase == "landing" and phase_left <= 0: phase = "grounded"
 if jump_left > 0 and grace_left > 0 and phase != "launch" and phase != "landing":
  phase = "launch"
  phase_left = profile.launch_delay
  jump_left = 0
 if phase == "launch" and phase_left <= 0:
  velocity.y = profile.jump_speed
  grounded = false
  grace_left = 0
  phase = "airborne"
  jump_count += 1
 var direction := Basis(Vector3.UP,camera_yaw) * Vector3(cmd.move.x,0,cmd.move.y)
 var horizontal := Vector3.ZERO
 if reference_enabled:
  var local_delta := Vector3.ZERO
  if not reference_motion.preview_clip.is_empty():
   local_delta = reference_motion.step(0,false,false,dt)
  elif phase=="launch": reference_motion.force_action("JUMP_launch",dt)
  elif phase=="landing": reference_motion.force_action("JUMP_land",dt)
  elif not grounded: reference_motion.force_action("JUMP_glide",dt)
  else:
   local_delta = reference_motion.step(direction.length(),cmd.sprint and not cmd.aim and (actions.profile.allow_sprint_all_guns or not weapon.profile.heavy),cmd.walk,dt)
  if not reference_motion.heading_locked and (direction.length_squared()>0.01 or cmd.aim):
   var angle := camera_yaw if cmd.aim else atan2(-direction.x,-direction.z)
   facing = rotate_toward(facing,angle,profile.turn_rate*dt)
  visual.rotation.y = facing
  if grounded and phase!="launch": drive_velocity = Basis(Vector3.UP,facing)*local_delta/maxf(0.00001,dt)
  if grounded and cmd.aim:
   drive_velocity = direction*Vector2(local_delta.x,local_delta.z).length()/maxf(0.00001,dt)*actions.profile.aim_movement_multiplier
  horizontal = drive_velocity
  if grounded: horizontal = horizontal.slide(support_normal)
  velocity.x = horizontal.x
  velocity.z = horizontal.z
  if grounded and velocity.y<=0: velocity.y = horizontal.y
  else: velocity.y -= profile.gravity*dt
 else:
  var speed := profile.sprint_speed if cmd.sprint else profile.speed
  if cmd.aim: speed *= profile.aim_multiplier
  if phase == "launch" or phase == "landing": speed = 0
  var target := direction * speed
  horizontal = drive_velocity
  var rate := profile.acceleration if direction.length_squared()>0 else profile.deceleration
  if not grounded: rate = profile.air_acceleration
  horizontal = horizontal.move_toward(target,rate*dt)
  drive_velocity = horizontal
  if grounded:
   horizontal = horizontal.slide(support_normal)
  velocity.x = horizontal.x
  velocity.z = horizontal.z
  if grounded and velocity.y <= 0: velocity.y = horizontal.y
  else: velocity.y -= profile.gravity*dt
  if direction.length_squared()>0.01 or cmd.aim:
   var angle := camera_yaw if cmd.aim else atan2(-direction.x,-direction.z)
   facing = rotate_toward(facing,angle,profile.turn_rate*dt)
   visual.rotation.y = facing
 var was_grounded := grounded
 var impact := velocity.y
 var motion := velocity*dt
 var obstruction := KinematicCollision3D.new()
 if was_grounded and phase != "launch" and Vector2(motion.x,motion.z).length()>0.0001 and test_move(global_transform,Vector3(motion.x,0,motion.z),obstruction):
  if obstruction.get_normal().y < 0.98:
   if try_step(Vector3(motion.x,0,motion.z)):
    velocity.y = 0
    return
 grounded = false
 for iteration in range(4):
  if motion.length_squared()<0.00000001: break
  var hit := move_and_collide(motion,false,0.002)
  if hit == null: break
  var normal := hit.get_normal()
  last_normal = normal
  if normal.y >= slope_cos() and velocity.y <= 0:
   grounded = true
   support_normal = normal
  var collider := hit.get_collider()
  if collider is RigidBody3D:
   var closing := maxf(0.0,-velocity.dot(normal))
   collider.apply_impulse(-normal*minf(closing*profile.push_mass,150.0),hit.get_position()-collider.global_position)
  motion = hit.get_remainder().slide(normal)
  velocity = velocity.slide(normal)
  # Steep surfaces must not turn horizontal input into upward climbing.
  if normal.y > 0 and normal.y < slope_cos() and was_grounded:
   velocity.y = minf(velocity.y,0)
   motion.y = minf(motion.y,0)
 if (velocity.y <= 0 or was_grounded) and phase != "launch":
  var floor_hit := KinematicCollision3D.new()
  if test_move(global_transform,Vector3.DOWN*profile.snap_distance,floor_hit) and floor_hit.get_normal().y >= slope_cos():
   move_and_collide(Vector3.DOWN*profile.snap_distance,false,0.002)
   grounded = true
   support_normal = floor_hit.get_normal()
   velocity.y = 0
 # The capsule may hit a stair riser before its bottom reaches the floor.
 # A center support ray preserves support in that case without accepting
 # the riser itself as a walkable slope.
 if not grounded and (velocity.y <= 0 or was_grounded) and phase != "launch":
  var probe := PhysicsRayQueryParameters3D.create(global_position,global_position-Vector3.UP*(0.90+profile.snap_distance),13,[get_rid()])
  var support := get_world_3d().direct_space_state.intersect_ray(probe)
  if not support.is_empty() and support.normal.y >= slope_cos():
   grounded = true
   support_normal = support.normal
   velocity.y = 0
 if grounded:
  if not was_grounded and impact < -1:
   last_impact_speed = -impact
   landing_count += 1
   phase = "landing"
   phase_left = profile.landing_delay
  elif phase != "launch" and phase != "landing": phase = "grounded"
 elif phase != "launch": phase = "airborne"
func slope_cos() -> float:
 return cos(deg_to_rad(profile.max_slope_degrees))
func try_step(horizontal: Vector3) -> bool:
 var rise := Vector3.UP*profile.step_height
 if test_move(global_transform,rise): return false
 var elevated := global_transform.translated(rise)
 if test_move(elevated,horizontal): return false
 elevated.origin += horizontal
 var down := KinematicCollision3D.new()
 if not test_move(elevated,Vector3.DOWN*(profile.step_height+profile.snap_distance),down): return false
 if down.get_normal().y < slope_cos(): return false
 var old_y := global_position.y
 global_transform = elevated
 move_and_collide(Vector3.DOWN*(profile.step_height+profile.snap_distance),false,0.002)
 last_step = global_position.y-old_y
 grounded = true
 support_normal = down.get_normal()
 return true
func ignore_vehicle_until_restored(body: PhysicsBody3D) -> void:
 ignored_vehicle = body
 add_collision_exception_with(body)
 collision_grace = 0.1
func set_embarked(value: bool) -> void:
 control_enabled = not value
 collision_layer = 0 if value else (10 if reference_enabled else 2)
 collision_mask = 0 if value else (15 if reference_enabled else 13)
 visible = not value
 velocity = Vector3.ZERO
func reset_at(where: Vector3) -> void:
 global_position = where
 force_update_transform()
 PhysicsServer3D.body_set_state(get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,global_transform)
 velocity = Vector3.ZERO
 drive_velocity = Vector3.ZERO
 grounded = false
 if reference_enabled:
  reference_motion.phase = "idle"
  reference_motion.was_sprinting = false
  reference_motion.set_clip("IDLE_stance")
 jump_left = 0
 grace_left = 0
 phase_left = 0
 phase = "airborne"

