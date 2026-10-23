class_name ActorFallState
extends RefCounted
## Per-actor trajectory evidence; the motor owns collision and health owns damage.
signal landed(impact_speed: float, damage: float)
var profile: FallProfile = preload("res://tuning/fall.tres")
var air_seconds := 0.0
var descent_time := 0.0
var peak_height := 0.0
var drop := 0.0
var tracked := false
var falling := false
var fall_time := 0.0
var hard_landing := false
var last_impact_speed := 0.0
var last_damage := 0.0
var landing_events := 0
func reset() -> void:
 air_seconds=0;descent_time=0;peak_height=0;drop=0;tracked=false
 falling=false;fall_time=0;hard_landing=false;last_impact_speed=0;last_damage=0
func observe_air(height: float, vertical_speed: float, dt: float) -> void:
 if not tracked:
  tracked=true;peak_height=height;hard_landing=false
 air_seconds+=dt
 peak_height=maxf(peak_height,height)
 drop=maxf(0,peak_height-height)
 descent_time=descent_time+dt if vertical_speed< -profile.descent_speed else 0.0
 if descent_time>=profile.descent_seconds and drop>=profile.minimum_drop:falling=true
 if falling:fall_time+=dt
func air_clip(actions: ActorActionState) -> String:
 var first:=actions.resolve(profile.fall_clips)
 return first if fall_time<=actions.motion.duration(first) else actions.resolve(profile.glide_clips)
func pose_time(actions: ActorActionState) -> float:
 var first_duration:=actions.motion.duration(actions.resolve(profile.fall_clips))
 if fall_time<=first_duration:return fall_time
 return fposmod(fall_time-first_duration,maxf(0.001,actions.motion.duration(actions.resolve(profile.glide_clips))))
func land(speed: float) -> float:
 if not tracked:return 0
 last_impact_speed=maxf(0,speed)
 var qualified:=air_seconds>=profile.minimum_air_seconds and drop>=profile.minimum_drop
 hard_landing=qualified and speed>=profile.hard_landing_speed
 last_damage=minf(profile.maximum_damage,pow(maxf(0,speed-profile.safe_impact_speed),2)*profile.damage_coefficient) if qualified and profile.damage_enabled else 0.0
 tracked=false;falling=false;fall_time=0;air_seconds=0;descent_time=0;drop=0
 landing_events+=1
 landed.emit(last_impact_speed,last_damage)
 return last_damage
static func closing_speed(incoming: Vector3, normal: Vector3, body: Object, point: Vector3) -> float:
 var support_velocity:=Vector3.ZERO
 if body is RigidBody3D:
  support_velocity=body.linear_velocity+body.angular_velocity.cross(point-body.global_position)
 elif body is StaticBody3D:
  support_velocity=body.constant_linear_velocity+body.constant_angular_velocity.cross(point-body.global_position)
 return maxf(0,-(incoming-support_velocity).dot(normal))
