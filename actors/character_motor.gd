class_name CharacterMotor
extends CharacterBody3D
## CharacterBody supplies swept collision only; acceleration, support, steps,
## sliding, launch and landing policy belong to this component.
@export var profile: MovementProfile
@onready var visual: Node3D = $Visual
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
func tick(cmd: GameplayCommand, camera_yaw: float, dt: float) -> void:
 if not control_enabled:
  velocity = Vector3.ZERO
  return
 if is_instance_valid(ignored_vehicle):
  collision_grace -= dt
  if collision_grace <= 0:
   remove_collision_exception_with(ignored_vehicle)
   ignored_vehicle = null
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
 var speed := profile.sprint_speed if cmd.sprint else profile.speed
 if cmd.aim: speed *= profile.aim_multiplier
 if phase == "launch" or phase == "landing": speed = 0
 var target := direction * speed
 var horizontal := drive_velocity
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
 collision_layer = 0 if value else 2
 collision_mask = 0 if value else 13
 visible = not value
 velocity = Vector3.ZERO
func reset_at(where: Vector3) -> void:
 global_position = where
 force_update_transform()
 PhysicsServer3D.body_set_state(get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,global_transform)
 velocity = Vector3.ZERO
 drive_velocity = Vector3.ZERO
 grounded = false
 jump_left = 0
 grace_left = 0
 phase_left = 0
 phase = "airborne"
