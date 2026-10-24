class_name ActorLandingState
extends RefCounted
## One action clock drives the landing pose and swept planar root displacement.
var profile:LandingProfile=preload("res://tuning/landing.tres")
var clip:=""
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
var motion:ReferenceMotion
func reset() -> void:
 clip="";time=0;previous_time=0;duration=0;weight=0;hard=false;active=false;travel=Vector3.ZERO
func start(actions:ActorActionState,air:float,drop:float,impact:float,speed:float,is_hard:bool) -> bool:
 if air<profile.minimum_air_seconds or drop<profile.minimum_drop or impact<profile.minimum_impact_speed:return false
 motion=actions.motion
 clip=actions.resolve(profile.standing_clips if is_hard or speed<profile.moving_min_speed else profile.moving_clips)
 if clip.is_empty():return false
 duration=motion.duration(clip);time=0;previous_time=0;weight=0;hard=is_hard;events+=1;active=true;travel=Vector3.ZERO
 var stride:=motion.segment(clip,0,duration);stride.y=0
 playback_rate=clampf(speed/maxf(0.1,stride.length()/maxf(0.01,duration)),profile.minimum_moving_playback,profile.maximum_moving_playback) if not hard and speed>=profile.moving_min_speed else 1.0
 return true
func tick(dt:float) -> void:
 travel=Vector3.ZERO
 if not active:return
 previous_time=time
 time=minf(time+dt*playback_rate,duration)
 travel=motion.segment(clip,previous_time,time);travel.y=0
 var fade:=minf(clampf(time/maxf(0.001,profile.blend_in_seconds),0,1),clampf((duration-time)/maxf(0.001,profile.blend_out_seconds),0,1))
 weight=fade
 if time>=duration:active=false;weight=0
