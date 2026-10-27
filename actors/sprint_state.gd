class_name ActorSprintState
extends RefCounted
## Input-edge boost, independent of device repeat and render frame rate.
var profile: SprintProfile = preload("res://tuning/sprint.tres")
var active := false
var multiplier := 1.0
var grace := 0.0
var since_tap := 100.0
var previously_held := false
var taps := 0
func reset() -> void:
 active=false;multiplier=1.0;grace=0;previously_held=false;since_tap=100
func tick(cmd: GameplayCommand, permitted: bool, dt: float, classic:=false) -> void:
 if classic:
  active=permitted and cmd.sprint
  multiplier=1.0;grace=0;previously_held=cmd.sprint
  return
 since_tap+=dt
 var edge:=cmd.sprint_pressed or (cmd.sprint and not previously_held)
 previously_held=cmd.sprint
 if not permitted:
  active=false;multiplier=1.0;grace=0
  return
 var was_active:=active
 grace=maxf(0,grace-dt)
 if cmd.sprint or edge:grace=profile.release_grace_seconds
 active=cmd.sprint or grace>0
 multiplier=move_toward(multiplier,1.0,profile.bonus_decay_per_second*dt)
 # Holding starts ordinary sprint. Only subsequent distinct presses build boost.
 if edge and was_active and since_tap>=profile.minimum_tap_interval:
  multiplier=minf(maxf(1,profile.maximum_multiplier),multiplier+profile.tap_gain)
  since_tap=0;taps+=1
 elif edge and not was_active:since_tap=0
 if not active:multiplier=1.0
