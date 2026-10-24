class_name ActorLandingState
extends RefCounted
## Visual impact timing is independent of movement recovery timing.
var profile:LandingProfile=preload("res://tuning/landing.tres")
var clip:=""
var time:=0.0
var duration:=0.0
var weight:=0.0
var events:=0
var hard:=false
func reset() -> void:
 clip="";time=0;duration=0;weight=0;hard=false
func start(actions:ActorActionState,air:float,drop:float,impact:float,speed:float,is_hard:bool) -> bool:
 if air<profile.minimum_air_seconds or drop<profile.minimum_drop or impact<profile.minimum_impact_speed:return false
 clip=actions.resolve(profile.standing_clips if is_hard or speed<profile.running_speed else profile.moving_clips)
 if clip.is_empty():return false
 duration=actions.motion.duration(clip);time=0;weight=0;hard=is_hard;events+=1
 return true
func tick(dt:float) -> void:
 if clip.is_empty():return
 time=minf(time+dt,duration)
 var fade:=minf(clampf(time/maxf(0.001,profile.blend_in_seconds),0,1),clampf((duration-time)/maxf(0.001,profile.blend_out_seconds),0,1))
 weight=fade
 if time>=duration:clip="";weight=0
