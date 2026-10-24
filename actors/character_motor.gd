class_name CharacterMotor
extends CharacterBody3D
## CharacterBody supplies swept collision only; acceleration, support, steps,
## sliding, launch and landing policy belong to this component.
signal attacked(event: DamageEvent)
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
var reaction_body: PedReactionBody
var corpse_hitbox: CorpseHitbox
var corpse_retired := false
var impact_cooldown := 0.0
var down_time := 0.0
var occupant_hitbox: OccupantHitbox
var normal_shape: Shape3D
var stance := CharacterStance.new()
var fall := ActorFallState.new()
var landing := ActorLandingState.new()
var sprint := ActorSprintState.new()
var jump_forward := Vector3.ZERO
var blocked_jump := false
var low_shape := SphereShape3D.new()
var grounded := false
var support_normal := Vector3.UP
var phase := "airborne"
var control_enabled := true
var interaction_holstered := false
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
 add_to_group("combat_actors")
 weapon = WeaponController.new()
 weapon.actor = self
 weapon.profile = preload("res://tuning/weapon.tres")
 add_child(weapon)
 reaction_body = PedReactionBody.new()
 reaction_body.configure(self)
 add_child(reaction_body)
 corpse_hitbox=CorpseHitbox.new()
 corpse_hitbox.configure(self)
 add_child(corpse_hitbox)
 health = PedHealth.new()
 add_child(health)
 occupant_hitbox = OccupantHitbox.new()
 occupant_hitbox.collision_layer = 0
 occupant_hitbox.collision_mask = 0
 occupant_hitbox.monitoring = false
 var occupant_shape := CollisionShape3D.new()
 var torso := CapsuleShape3D.new()
 torso.radius = 0.22
 torso.height = 0.9
 occupant_shape.shape = torso
 occupant_shape.position.y = 0.25
 occupant_hitbox.add_child(occupant_shape)
 occupant_hitbox.actor = self
 add_child(occupant_hitbox)
 normal_shape = $CollisionShape3D.shape
 stance.configure(self)
 low_shape.radius = 0.32
 health.depleted.connect(func():
  control_enabled = false
  actions.begin_life("dying")
  set_reaction_shape())
 weapon.shot_fired.connect(func(_a: Vector3,_b: Vector3,_hit: bool): actions.fire(weapon.profile.interval,weapon.profile.native_fire_recovery))
func configure_reference(db: ImportedGameplayDatabase, stat: String, library: AnimationLibrary) -> void:
 archetype = stat
 var record := db.find_record("ped_stats",stat)
 profile = profile.duplicate()
 if not record.is_empty():
  # Source heading rates use normalized ticks (50/s), not degrees/second.
  profile.turn_rate = deg_to_rad(record.heading_rate_per_normalized_tick*50.0)
  health.defense_multiplier = 0.33 if stat=="STAT_PLAYER" else record.defense_multiplier
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
 profile.gravity = LegacyPhysicsUnits.acceleration(0.008)
 profile.jump_speed = LegacyPhysicsUnits.player_jump_speed()
 collision_layer = 10
 collision_mask = 15
 reference_enabled = true
 for child in visual.get_children(): child.visible = false
 reference_pose = ReferencePose.new()
 reference_pose.motion = reference_motion
 visual.add_child(reference_pose)
func receive_damage(amount: float, point: Vector3, direction: Vector3) -> void:
 receive_hit(DamageEvent.make(amount,point,direction))
func receive_hit(event: DamageEvent) -> void:
 if health.health<=0:
  if event.kind=="melee":actions.react_on_floor(reaction_body.rest.face_down)
  return
 if event.kind=="bullet" and reference_pose is SkinnedMotionVisual:
  var pose := reference_pose as SkinnedMotionVisual
  var head := pose.skeleton.find_bone("Head")
  if head>=0 and event.point.distance_to(pose.skeleton.global_transform*pose.skeleton.get_bone_global_pose(head).origin)<0.3: event.part = "head"
 attacked.emit(event)
 actions.choose_reaction(event,facing,global_position)
 reaction_velocity += event.direction*minf(2.0,event.amount*0.02)
 health.receive(event.amount)
 if actions.life in ["down","getting_up"] and event.kind=="melee":actions.react_on_floor(reaction_body.rest.face_down)
 if health.health>0:
  if event.amount>=actions.profile.hit_interrupt_damage:weapon.melee.cancel();actions.firing_left=0
  actions.react(event)
  if event.kind=="melee" and event.amount>=actions.profile.melee_knockdown_damage and actions.life=="alive" and grounded:
   actions.begin_life("down");control_enabled=false;down_time=0
   reaction_body.launch_velocity(global_position,facing,event.direction*2.5+Vector3.UP*1.5)
func set_reaction_shape() -> void:
 collision_layer = 8 if health.health>0 else 0
 collision_mask = 1
 $CollisionShape3D.set_deferred("shape",low_shape)
 $CollisionShape3D.set_deferred("position",Vector3(0,-0.58,0))
func receive_vehicle_impact(car: DriveVehicle, closing_speed: float, direction: Vector3) -> void:
 if impact_cooldown>0 or health.health<=0 or not visible or closing_speed<reaction_body.profile.minimum_speed: return
 impact_cooldown = reaction_body.profile.cooldown_seconds
 var impact := reaction_body.profile
 actions.choose_reaction(DamageEvent.make(0,global_position,direction,"vehicle",car),facing,global_position)
 health.receive(pow(maxf(0,closing_speed-impact.damage_speed_threshold),2)*impact.damage_coefficient)
 if health.health>0: actions.begin_life("down")
 down_time = 0
 control_enabled = false
 # Standing capsule hands ownership to a solid Jolt torso, never to a no-contact mover.
 reaction_body.launch(car,closing_speed,direction)
func tick_reaction(dt: float) -> void:
 down_time += dt
 actions.tick(GameplayCommand.new(),weapon,dt)
 if corpse_retired:return
 if reaction_body.active:
  reaction_body.follow_pose(dt)
  if health.health<=0:
   if reaction_body.rest.locked and reaction_body.rest.weight>=0.99 and reaction_body.presentation_settled:retire_corpse()
   return
  if actions.life=="down" and reaction_body.can_recover():
   actions.life = "getting_up"
   actions.life_time = 0
   actions.life_clip = reaction_body.getup_clip()
   facing = reaction_body.rest.heading
   global_position = reaction_body.stand_position
   reaction_body.deactivate()
   $CollisionShape3D.shape = normal_shape
   $CollisionShape3D.position = Vector3.ZERO
   # The clear standing volume is reserved while get-up owns animation.
   collision_layer = 10 if reference_enabled else 2
   collision_mask = 15
  return
 reaction_velocity.x = move_toward(reaction_velocity.x,0,4.0*dt)
 reaction_velocity.z = move_toward(reaction_velocity.z,0,4.0*dt)
 reaction_velocity.y -= profile.gravity*dt
 grounded = false
 var hit := move_and_collide(reaction_velocity*dt,false,0.002)
 if hit!=null:
  reaction_velocity = reaction_velocity.slide(hit.get_normal())
  grounded = hit.get_normal().y>=slope_cos()
 velocity = reaction_velocity
 if health.health<=0:
  if grounded and actions.life=="dead":retire_corpse()
  return
 if actions.life=="down" and down_time>actions.profile.knockdown_seconds+maxf(0.1,reference_motion.duration(actions.life_clip) if reference_enabled else 0.6):
  var query := PhysicsShapeQueryParameters3D.new()
  query.shape = normal_shape
  query.transform = global_transform
  query.collision_mask = 15
  query.exclude = [get_rid()]
  if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
   actions.life = "getting_up"
   actions.life_time = 0
   actions.life_clip = reaction_body.getup_clip()
   facing = reaction_body.rest.heading
 if actions.life=="getting_up" and actions.life_time>=maxf(0.5,reference_motion.duration(actions.life_clip) if reference_enabled else 0.5):
  restore_control()
func restore_control() -> void:
 corpse_retired=false
 if is_instance_valid(corpse_hitbox):corpse_hitbox.clear()
 landing.reset()
 interaction_holstered = false
 sprint.reset()
 fall.reset()
 if reference_pose!=null:reference_pose.scale=Vector3.ONE
 if is_instance_valid(occupant_hitbox): occupant_hitbox.collision_layer = 0
 stance.reset()
 reaction_body.deactivate()
 actions.reset()
 control_enabled = true
 collision_layer = 10 if reference_enabled else 2
 collision_mask = 15 if reference_enabled else 13
 $CollisionShape3D.shape = normal_shape
 $CollisionShape3D.position = Vector3.ZERO
 reaction_velocity = Vector3.ZERO
 if reference_enabled:
  reference_motion.vehicle_layers.clear()
  reference_motion.phase = "idle"
  reference_motion.set_clip("IDLE_stance")
func respawn(where: Vector3) -> void:
 health.reset()
 restore_control()
 reset_at(where)
func tick(cmd: GameplayCommand, camera_yaw: float, dt: float) -> void:
 landing.tick(dt)
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
   if reference_motion.phase=="seated": actions.upper_allowed = false
  velocity = Vector3.ZERO
  return
 stance.read_command(cmd)
 last_step = 0.0
 jump_left = maxf(0.0,jump_left-dt)
 grace_left = profile.coyote_time if grounded else maxf(0.0,grace_left-dt)
 if cmd.jump: jump_left = profile.jump_buffer
 phase_left = maxf(0.0,phase_left-dt)
 if phase == "landing" and phase_left <= 0:
  phase = "grounded"
  blocked_jump = false
  fall.hard_landing = false
 if jump_left > 0 and grace_left > 0 and phase != "launch" and phase != "landing" and not stance.crouched and not actions.full_body_busy() and not (reference_enabled and reference_motion.heading_locked):
  if reference_enabled:
   var desired := LegacyPhysicsUnits.jump_forward(reference_motion.intensity,reference_motion.was_sprinting)
   jump_forward = Basis(Vector3.UP,facing)*Vector3(0,0,-desired)
   if drive_velocity.length()>desired: jump_forward = drive_velocity
  phase = "launch"
  phase_left = profile.launch_delay
  jump_left = 0
 if phase == "launch" and phase_left <= 0 and reference_enabled and not jump_has_clearance():
  phase = "landing"
  phase_left = maxf(0.1,reference_motion.duration("HIT_wall"))
  blocked_jump = true
  drive_velocity = Vector3.ZERO
 if phase == "launch" and phase_left <= 0:
  if reference_enabled: drive_velocity = jump_forward
  velocity.y = profile.jump_speed
  grounded = false
  grace_left = 0
  phase = "airborne"
  jump_count += 1
 if not grounded: fall.observe_air(global_position.y,velocity.y,dt)
 if fall.profile.physical_tumble_enabled and fall.falling and fall.drop>=fall.profile.physical_tumble_drop and velocity.y<= -fall.profile.physical_tumble_speed:
  weapon.melee.cancel()
  actions.begin_life("down")
  actions.life_clip=actions.resolve(fall.profile.fall_clips)
  actions.life_time=0
  control_enabled=false
  reaction_body.launch_velocity(global_position,facing,velocity,true)
  reaction_body.follow_pose(dt)
  return
 var direction := Basis(Vector3.UP,camera_yaw) * Vector3(cmd.move.x,0,cmd.move.y)
 var sprint_allowed := grounded and phase=="grounded" and not stance.crouched and not cmd.walk and direction.length_squared()>0.01 and not cmd.aim and weapon.reload_left<=0 and (not cmd.fire or weapon.profile.kind=="melee") and (not actions.melee_active or actions.melee_mobile) and (actions.profile.allow_sprint_all_guns or not weapon.profile.heavy)
 sprint.tick(cmd,sprint_allowed,dt)
 var horizontal := Vector3.ZERO
 if reference_enabled:
  var local_delta := Vector3.ZERO
  if not reference_motion.preview_clip.is_empty():
   local_delta = reference_motion.step(0,false,false,dt)
  elif actions.melee_active and not actions.melee_mobile:
   reference_motion.force_action(actions.melee_clip,0)
   reference_motion.time = actions.melee_time
   drive_velocity = Basis(Vector3.UP,facing)*weapon.melee.root_delta()/maxf(0.00001,dt)+direction*weapon.melee.profile.shuffle_speed
  elif stance.crouched: reference_motion.force_action(stance.profile.crouch_clip,dt)
  elif phase=="launch": reference_motion.force_action("JUMP_launch",dt)
  elif phase=="landing": reference_motion.force_action("HIT_wall" if blocked_jump else (actions.resolve(fall.profile.landing_clips) if fall.hard_landing else "JUMP_land"),dt)
  elif not grounded:
   reference_motion.force_action(fall.air_clip(actions) if fall.falling else "JUMP_glide",dt)
   if fall.falling:reference_motion.time=fall.pose_time(actions)
  else:
   if actions.melee_mobile and reference_motion.phase=="action":
    reference_motion.phase="move"
    reference_motion.intensity=1.0 if cmd.walk else 2.0
   local_delta = reference_motion.step(direction.length(),sprint.active,cmd.walk,dt*clampf(cmd.locomotion_scale,0,1)*(sprint.multiplier if sprint.active else 1.0))
  if (not actions.melee_active or actions.melee_mobile) and not reference_motion.heading_locked and (direction.length_squared()>0.01 or cmd.aim or (cmd.fire and weapon.profile.two_handed)):
   var angle := camera_yaw if cmd.aim or (cmd.fire and weapon.profile.two_handed and not actions.melee_active) else atan2(-direction.x,-direction.z)
   facing = rotate_toward(facing,angle,(weapon.melee.profile.steering_rate if actions.melee_mobile else profile.turn_rate)*dt)
  visual.rotation.y = facing
  if grounded and phase!="launch" and (not actions.melee_active or actions.melee_mobile):
   var target_velocity:=Basis(Vector3.UP,facing)*local_delta/maxf(0.00001,dt)
   var rate:=reference_motion.gait.ground_acceleration if target_velocity.length()>drive_velocity.length() else reference_motion.gait.ground_deceleration
   drive_velocity=drive_velocity.move_toward(target_velocity,rate*dt)
  if stance.crouched:
   drive_velocity = direction*profile.speed*stance.profile.move_multiplier if stance.profile.allow_crouch_walk else Vector3.ZERO
  if grounded and cmd.aim and not stance.crouched:
   drive_velocity = direction*Vector2(local_delta.x,local_delta.z).length()/maxf(0.00001,dt)*actions.profile.aim_movement_multiplier
  horizontal = drive_velocity
  if grounded: horizontal = horizontal.slide(support_normal)
  velocity.x = horizontal.x
  velocity.z = horizontal.z
  if grounded and phase not in ["launch","airborne"]: velocity.y = horizontal.y
  else: velocity.y -= profile.gravity*dt
 else:
  var speed := (profile.sprint_speed*sprint.multiplier if sprint.active else profile.speed)*clampf(cmd.locomotion_scale,0,1)
  if cmd.aim: speed *= profile.aim_multiplier
  if stance.crouched: speed *= stance.profile.move_multiplier if stance.profile.allow_crouch_walk else 0.0
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
  if grounded and phase not in ["launch","airborne"]: velocity.y = horizontal.y
  else: velocity.y -= profile.gravity*dt
  if direction.length_squared()>0.01 or cmd.aim or (cmd.fire and weapon.profile.two_handed):
   var angle := camera_yaw if cmd.aim or (cmd.fire and weapon.profile.two_handed) else atan2(-direction.x,-direction.z)
   facing = rotate_toward(facing,angle,profile.turn_rate*dt)
   visual.rotation.y = facing
 if actions.reaction_left>0:
  velocity.x*=actions.profile.hit_move_multiplier;velocity.z*=actions.profile.hit_move_multiplier
 velocity+=reaction_velocity
 reaction_velocity=reaction_velocity.move_toward(Vector3.ZERO,actions.profile.hit_impulse_decay*dt)
 actions.upper_allowed = actions.upper_allowed and phase=="grounded" and control_enabled
 var was_grounded := grounded
 var impact := velocity.y
 var incoming := velocity
 var landing_speed := 0.0
 var motion := velocity*dt
 var obstruction := KinematicCollision3D.new()
 if was_grounded and phase != "launch" and Vector2(motion.x,motion.z).length()>0.0001 and test_move(global_transform,Vector3(motion.x,0,motion.z),obstruction):
  if obstruction.get_normal().y<0.98 and not obstruction.get_collider() is RigidBody3D:
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
   landing_speed = maxf(landing_speed,ActorFallState.closing_speed(incoming,normal,hit.get_collider(),hit.get_position()))
  var collider := hit.get_collider()
  if collider is RigidBody3D and not collider is DriveVehicle:
   var point_velocity: Vector3 = collider.linear_velocity+collider.angular_velocity.cross(hit.get_position()-collider.global_position)
   var closing := maxf(0.0,-(velocity-point_velocity).dot(normal))
   var reduced_mass: float = profile.push_mass*collider.mass/(profile.push_mass+collider.mass)
   collider.apply_impulse(-normal*minf(closing*reduced_mass,150.0),hit.get_position()-collider.global_position)
  var before_y := velocity.y
  var remainder_y := hit.get_remainder().y
  motion = hit.get_remainder().slide(normal)
  velocity = velocity.slide(normal)
  # Steep surfaces must not turn horizontal input into upward climbing.
  if normal.y<slope_cos():
   # Never convert replenished horizontal intent into vertical energy.
   velocity.y = minf(velocity.y,before_y)
   motion.y = minf(motion.y,remainder_y)
   var wall := Vector3(normal.x,0,normal.z).normalized()
   if wall.length_squared()>0.1: drive_velocity = drive_velocity.slide(wall)
   drive_velocity.y = 0
 if (velocity.y <= 0 or was_grounded) and phase != "launch":
  var floor_hit := KinematicCollision3D.new()
  if test_move(global_transform,Vector3.DOWN*profile.snap_distance,floor_hit) and floor_hit.get_normal().y >= slope_cos():
   move_and_collide(Vector3.DOWN*profile.snap_distance,false,0.002)
   grounded = true
   support_normal = floor_hit.get_normal()
   landing_speed = maxf(landing_speed,ActorFallState.closing_speed(incoming,support_normal,floor_hit.get_collider(),floor_hit.get_position()))
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
   landing_speed = maxf(landing_speed,ActorFallState.closing_speed(incoming,support_normal,support.collider,support.position))
   velocity.y = 0
 if grounded:
  if not was_grounded and impact < -1:
   last_impact_speed = -impact
   landing_count += 1
   var air_time:=fall.air_seconds
   var drop_height:=fall.drop
   var amount := fall.land(landing_speed)
   if reference_enabled:landing.start(actions,air_time,drop_height,landing_speed,drive_velocity.length(),fall.hard_landing)
   if reference_enabled and not fall.hard_landing:reference_motion.phase="move" if cmd.move.length_squared()>0.01 else "idle"
   phase = "landing" if fall.hard_landing else "grounded"
   phase_left = profile.landing_delay if fall.hard_landing else 0.0
   if fall.hard_landing:
    weapon.melee.cancel()
    drive_velocity = Vector3.ZERO
    if reference_enabled:phase_left=maxf(phase_left,reference_motion.duration(actions.resolve(fall.profile.landing_clips)))
   if amount>0:
    actions.next_death = actions.resolve(fall.profile.death_clips)
    health.receive(amount,false)
  elif phase != "launch" and phase != "landing":
   if fall.tracked:fall.land(landing_speed)
   phase = "grounded"
 elif phase != "launch": phase = "falling" if fall.falling else "airborne"
func receive_fall_landing(speed: float) -> void:
 if health.health<=0:return
 var amount:=fall.land(speed)
 if amount>0:
  actions.next_death=actions.resolve(fall.profile.death_clips)
  health.receive(amount,false)
func retire_corpse() -> void:
 corpse_retired=true
 reaction_body.active=false;reaction_body.freeze=true;reaction_body.collision_layer=0;reaction_body.collision_mask=0
 reaction_body.linear_velocity=Vector3.ZERO;reaction_body.angular_velocity=Vector3.ZERO
 collision_layer=0;collision_mask=0;reaction_velocity=Vector3.ZERO;velocity=Vector3.ZERO
 var center:=global_position
 if reference_pose is SkinnedMotionVisual:
  var pose:=reference_pose as SkinnedMotionVisual
  center=pose.skeleton.global_transform*pose.skeleton.get_bone_global_pose(pose.skeleton.find_bone("Pelvis")).origin
 corpse_hitbox.activate(center,visual.global_basis)
func jump_has_clearance() -> bool:
 var shape := SphereShape3D.new()
 shape.radius = 0.25
 var query := PhysicsShapeQueryParameters3D.new()
 query.shape = shape
 query.collision_mask = 13
 query.exclude = [get_rid(),reaction_body.get_rid()]
 var forward := Basis(Vector3.UP,facing)*Vector3.FORWARD
 for pair in [[0.09,0.80],[0.24,0.95]]:
  query.transform = Transform3D(Basis.IDENTITY,global_position+forward*pair[0]+Vector3.UP*pair[1])
  if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
 return true
func can_use_weapon() -> bool:
 return control_enabled and not interaction_holstered and health.health>0 and actions.life=="alive" and grounded and phase=="grounded" and not actions.full_body_busy() and actions.reaction_left<=0
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
 if down.get_normal().y < slope_cos():
  # Capsule edge normals can be steep even when the actual stair tread is flat.
  # Probe the leading foot, then raise only by a verified static tread height.
  var toe := global_position+horizontal+horizontal.normalized()*float((normal_shape as CapsuleShape3D).radius)
  var ray := PhysicsRayQueryParameters3D.create(toe+rise,toe-Vector3.UP*1.0,13,[get_rid()])
  var support := get_world_3d().direct_space_state.intersect_ray(ray)
  if support.is_empty() or support.normal.y<slope_cos() or support.collider is RigidBody3D: return false
  var height: float = support.position.y-(global_position.y-0.9)
  if height<=0.01 or height>profile.step_height: return false
  var old := global_position.y
  global_position.y += height+0.002
  move_and_collide(horizontal,false,0.002)
  last_step = global_position.y-old
  grounded = true
  support_normal = support.normal
  return true
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
 sprint.reset()
 fall.reset()
 weapon.melee.cancel()
 if not value:
  visual.rotation = Vector3(0,facing,0)
  if reference_pose!=null:reference_pose.scale=Vector3.ONE
 occupant_hitbox.collision_layer = 8 if value else 0
 control_enabled = not value
 collision_layer = 0 if value else (10 if reference_enabled else 2)
 collision_mask = 0 if value else (15 if reference_enabled else 13)
 visible = not value
 velocity = Vector3.ZERO
func reset_at(where: Vector3) -> void:
 landing.reset()
 sprint.reset()
 fall.reset()
 weapon.melee.cancel()
 global_position = where
 force_update_transform()
 PhysicsServer3D.body_set_state(get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,global_transform)
 velocity = Vector3.ZERO
 drive_velocity = Vector3.ZERO
 grounded = false
 if reference_enabled:
  reference_motion.phase = "idle"
  reference_motion.was_sprinting = false
  reference_motion.sprint_weight = 0
  reference_motion.set_clip("IDLE_stance")
 blocked_jump = false
 jump_left = 0
 grace_left = 0
 phase_left = 0
 phase = "airborne"

