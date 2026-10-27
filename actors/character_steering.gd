class_name CharacterSteering
extends RefCounted
## Camera-relative intent, body-relative travel; airborne heading is never input-driven.
var reversing := false
var error := 0.0
var pivoting:=false
func update(actor:CharacterMotor,direction:Vector3,aim_yaw:float,aiming:bool,dt:float) -> float:
 reversing=false;error=0
 if actor.actions.spatial_hit():return 0
 if not actor.grounded or actor.phase in ["launch","airborne","falling","landing"]:
  pivoting=false
  return direction.length()
 if direction.length_squared()<0.0001 and not aiming:pivoting=false;return 0
 var desired:=aim_yaw if aiming else atan2(-direction.x,-direction.z)
 error=angle_difference(actor.facing,desired)
 if actor.profile.classic_revc:
  pivoting=false
  if not (actor.reference_enabled and actor.reference_motion.heading_locked):
   actor.facing=wrapf(rotate_toward(actor.facing,desired,actor.profile.turn_rate*dt),-PI,PI)
  return direction.length()
 var speed:=Vector2(actor.drive_velocity.x,actor.drive_velocity.z).length()
 var profile:=actor.profile
 reversing=not aiming and absf(error)>deg_to_rad(profile.reversal_resume_degrees if pivoting else profile.reversal_angle_degrees)
 pivoting=reversing
 if actor.reference_enabled and actor.reference_motion.heading_locked:return 0.0 if reversing else direction.length()
 var rate:=lerpf(profile.standing_turn_rate,profile.running_turn_rate,clampf(speed/profile.turn_speed_reference,0,1))
 if reversing and speed>profile.pivot_speed:rate=profile.braking_turn_rate
 if actor.actions.melee_mobile:rate=minf(rate,actor.weapon.melee.profile.steering_rate)
 actor.facing=wrapf(rotate_toward(actor.facing,desired,minf(profile.turn_rate,rate)*dt),-PI,PI)
 return 0.0 if reversing else direction.length()
