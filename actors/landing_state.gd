class_name ActorLandingState
extends RefCounted
## One clock drives contact compression, spatial follow-through and pose blending.
var profile:LandingProfile=preload("res://tuning/landing.tres")
var clip:=""
var follow_clip:=""
var kind:=""
var contact_end:=0.0
var follow_rate:=1.0
var time:=0.0
var duration:=0.0
var weight:=0.0
var events:=0
var hard:=false
var previous_time:=0.0
var playback_rate:=1.0
var heading:=0.0
var travel:=Vector3.ZERO
var active:=false
var travel_allowed:=true
var braking:=false
var queued_jump:=false
var motion:ReferenceMotion
func reset() -> void:
 clip="";follow_clip="";kind="";time=0;previous_time=0;duration=0;weight=0;hard=false;active=false;travel=Vector3.ZERO;travel_allowed=true;braking=false;queued_jump=false
func start(actions:ActorActionState,air:float,drop:float,impact:float,speed:float,is_hard:bool,was_jump:=false,intent:=Vector3.INF) -> bool:
 if air<profile.minimum_air_seconds or (not was_jump and (drop<profile.minimum_drop or impact<profile.minimum_impact_speed)):return false
 motion=actions.motion
 var moving:=speed>=profile.moving_min_speed
 var roll:=is_hard and speed>=profile.roll_minimum_speed and impact>=profile.roll_minimum_impact and impact<profile.roll_maximum_impact and drop<profile.roll_maximum_drop
 travel_allowed=moving;braking=false
 if intent.is_finite():
  var alignment:=intent.normalized().dot(Basis(Vector3.UP,heading)*Vector3.FORWARD) if intent.length_squared()>0.01 else 0.0
  travel_allowed=alignment>profile.continuation_dot
  braking=intent.length_squared()>0.01 and alignment< -profile.continuation_dot
 moving=moving and travel_allowed
 roll=roll and travel_allowed
 clip=actions.resolve(profile.roll_clips if roll else profile.contact_clips)
 if clip.is_empty():return false
 follow_clip=actions.resolve(profile.moving_clips) if moving and not is_hard else ""
 if follow_clip==clip:follow_clip=""
 kind="roll" if roll else ("moving" if not follow_clip.is_empty() else ("braking" if braking else "standing"))
 duration=motion.duration(clip);time=0;previous_time=0;weight=0;hard=is_hard;events+=1;active=true;travel=Vector3.ZERO
 playback_rate=profile.roll_playback if roll else 1.0
 queued_jump=false
 if not follow_clip.is_empty():
  contact_end=minf(profile.moving_contact_seconds,duration)
  var stride:=motion.segment(follow_clip,0,motion.duration(follow_clip));stride.y=0
  var desired:=clampf(speed/maxf(0.1,stride.length()/maxf(0.01,motion.duration(follow_clip))),profile.minimum_moving_playback,profile.maximum_moving_playback)
  follow_rate=minf(desired,motion.duration(follow_clip)/maxf(0.01,profile.moving_follow_seconds))
  duration=contact_end+motion.duration(follow_clip)/maxf(0.01,follow_rate)
 return true
func set_intent(intent:Vector3) -> void:
 if not active or not travel_allowed:return
 var alignment:=intent.normalized().dot(Basis(Vector3.UP,heading)*Vector3.FORWARD) if intent.length_squared()>0.01 else 0.0
 if alignment>profile.continuation_dot:return
 travel_allowed=false;braking=intent.length_squared()>0.01 and alignment< -profile.continuation_dot
 # Finish compression in place; do not replay a stride after input is released.
 if not follow_clip.is_empty():
  follow_clip="";duration=motion.duration(clip);time=minf(time,duration);playback_rate=1.0
  kind="braking" if braking else "standing"
func blend_at(at:float) -> float:
 return smoothstep(contact_end,contact_end+profile.contact_transition_seconds,at)
func follow_time(at:float) -> float:
 return clampf((at-contact_end)*follow_rate,0,motion.duration(follow_clip))
func contact_time(at:float) -> float:
 return minf(at,minf(motion.duration(clip),contact_end+profile.contact_transition_seconds))
func pose_layers() -> Array[Dictionary]:
 if follow_clip.is_empty():return [{"clip":clip,"time":time,"weight":1.0}]
 var blend:=blend_at(time)
 return [{"clip":clip,"time":contact_time(time),"weight":1.0-blend},{"clip":follow_clip,"time":follow_time(time),"weight":blend}]
func tick(dt:float) -> void:
 travel=Vector3.ZERO
 if not active:return
 previous_time=time
 time=minf(time+dt*playback_rate,duration)
 if follow_clip.is_empty():travel=motion.segment(clip,previous_time,time)
 else:
  var blend:=(blend_at(previous_time)+blend_at(time))*0.5
  travel=motion.segment(clip,contact_time(previous_time),contact_time(time))*(1.0-blend)+motion.segment(follow_clip,follow_time(previous_time),follow_time(time))*blend
 travel.y=0
 if not travel_allowed:travel=Vector3.ZERO
 weight=minf(clampf(time/maxf(0.001,profile.blend_in_seconds),0,1),clampf((duration-time)/maxf(0.001,profile.blend_out_seconds),0,1))
 if time>=duration:active=false;weight=0
