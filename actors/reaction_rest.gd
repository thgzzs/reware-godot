class_name ReactionRestState
extends RefCounted
var profile: ReactionRestProfile = preload("res://tuning/reaction_rest.tres")
var locked := false
var quiet_time := 0.0
var weight := 0.0
var face_down := true
var heading := 0.0
var original_heading := 0.0
var trajectory := Vector3.ZERO
func reset() -> void:
 locked=false;quiet_time=0;weight=0;trajectory=Vector3.ZERO
func begin(facing: float, velocity: Vector3) -> void:
 reset();original_heading=facing;heading=facing
 trajectory=Vector3(velocity.x,0,velocity.z)
func observe(supported: bool, velocity: Vector3, angular: Vector3, body_basis: Basis, dt: float) -> void:
 if velocity.length()>profile.unlock_speed or angular.length()>profile.unlock_angular_speed or not supported:
  locked=false;quiet_time=0
 if not locked:
  if supported and velocity.length()<=profile.linear_speed and angular.length()<=profile.angular_speed:
   quiet_time+=dt
   if quiet_time>=profile.contact_seconds:
    var forward:=Basis(Vector3.UP,original_heading)*Vector3.FORWARD
    var travel:=trajectory.normalized() if trajectory.length_squared()>0.01 else forward
    var alignment:=travel.dot(forward)
    face_down=alignment>=0 if absf(alignment)>0.2 else body_basis.y.dot(Vector3.UP)<0
    var facing_direction:=travel if face_down else -travel
    heading=atan2(-facing_direction.x,-facing_direction.z)
    locked=true
  else:quiet_time=0
 weight=move_toward(weight,1.0 if locked else 0.0,profile.blend_rate*dt)
func basis_on_floor(normal: Vector3) -> Basis:
 var up:=normal.normalized()
 var forward:=(Basis(Vector3.UP,heading)*Vector3.FORWARD).slide(up).normalized()
 if forward.length_squared()<0.1:forward=Vector3.FORWARD.slide(up).normalized()
 return Basis(forward.cross(up).normalized(),up,-forward).orthonormalized()
