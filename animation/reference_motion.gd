class_name ReferenceMotion
extends RefCounted
## Phase policy is original target code; clip displacement/timing comes from IFP.
var library: AnimationLibrary
var clip := "IDLE_stance"
var time := 0.0
var phase := "idle"
var cycle := 0.0
var intensity := 0.0
var heading_locked := false
var classic_revc := false
var was_sprinting := false
var gait: GaitProfile = preload("res://tuning/gait.tres")
var sprint_weight := 0.0
var walk_clip := "WALK_player"
var run_clip := "run_player"
var preview_clip := ""
var preview_time := 0.0
var preview_playing := true
var vehicle_layers: Array[Dictionary] = []
var roots := {}
var clip_names := {}
func _init(source: AnimationLibrary) -> void:
 library = source
 for name in library.get_animation_list():
  clip_names[String(name).to_lower()] = String(name)
  var a := library.get_animation(name)
  roots[name] = AnimationRigBinding.indices_for(a,"Root",0)[1]
func duration(name: String) -> float:
 return library.get_animation(name).length if library.has_animation(name) else 0.0
func set_clip(name: String, reset := true) -> void:
 if not library.has_animation(name): return
 if clip!=name:
  clip = name
  if reset: time = 0
func position_at(name: String, at: float) -> Vector3:
 if not roots.has(name) or roots[name]<0: return Vector3.ZERO
 return library.get_animation(name).position_track_interpolate(roots[name],clampf(at,0,duration(name)))
func segment(name: String, a: float, b: float) -> Vector3:
 return position_at(name,b)-position_at(name,a)
func loop_segment(name: String, a: float, b: float) -> Vector3:
 var length := duration(name)
 if length<=0 or b<=a: return Vector3.ZERO
 var start := fposmod(a,length)
 # A delayed/accelerated tick may cross several complete cycles.
 var finish := fposmod(b,length)
 var loops := floori(b/length)-floori(a/length)
 return segment(name,start,finish)+segment(name,0,length)*loops
func pose_layers() -> Array[Dictionary]:
 if phase=="seated" and not vehicle_layers.is_empty() and preview_clip.is_empty(): return vehicle_layers
 if not preview_clip.is_empty(): return [{"clip":preview_clip,"time":preview_time,"weight":1.0}]
 if phase=="move":
  var blend := clampf(intensity-1.0,0,1)
  var moving:=1.0 if classic_revc and intensity>0 else clampf(intensity,0,1)
  return [{"clip":"IDLE_stance","time":0.0,"weight":1.0-moving},{"clip":walk_clip,"time":cycle*duration(walk_clip),"weight":moving*(1.0-blend)*(1.0-sprint_weight)},{"clip":run_clip,"time":cycle*duration(run_clip),"weight":moving*blend*(1.0-sprint_weight)},{"clip":"sprint_civi","time":cycle*duration("sprint_civi"),"weight":moving*sprint_weight}]
 return [{"clip":clip,"time":time,"weight":1.0}]
func force_action(name: String, dt: float) -> void:
 # Exclusive actions must never sample stale walk/run layers.
 phase = "seated" if name=="CAR_sit" else "action"
 if clip!=name:
  set_clip(name)
  time=minf(dt,duration(name))
 else: time = minf(time+dt,duration(name))
func step(amount: float, sprint: bool, walk: bool, dt: float) -> Vector3:
 heading_locked = false
 if phase=="action" or phase=="seated":
  phase = "idle"
  was_sprinting = false
  sprint_weight = 0
 if not preview_clip.is_empty():
  if preview_playing: preview_time = fposmod(preview_time+dt,maxf(0.001,duration(preview_clip)))
  return Vector3.ZERO
 if phase=="stop" and amount>=0.01 and not classic_revc:
  phase="move"
  heading_locked=false
 if phase=="stop":
  heading_locked = true
  var old := time
  time = minf(time+dt,duration(clip))
  var delta := segment(clip,old,time)
  if time>=duration(clip)-0.000001:
   phase = "idle"
   intensity = 0
   was_sprinting = false
   set_clip("IDLE_stance")
  delta.y = 0
  return delta
 if amount<0.01:
  if was_sprinting:
   phase = "stop"
   set_clip("Run_stop" if cycle<0.5 else "Run_stopR")
   return step(amount,false,walk,dt)
  if classic_revc or phase=="idle" or intensity<=gait.deceleration*dt:
   phase="idle";intensity=0;sprint_weight=0
   set_clip("IDLE_stance");time=fposmod(time+dt,duration(clip))
   return Vector3.ZERO
 var target_intensity:=amount*(1.0 if walk else 2.0)
 intensity = minf(target_intensity,intensity+0.07*LegacyPhysicsUnits.TICKS_PER_SECOND*dt) if classic_revc else move_toward(intensity,target_intensity,(gait.acceleration if target_intensity>intensity else gait.deceleration)*dt)
 if phase=="idle":
  phase = "start"
  set_clip("WALK_start")
 if phase=="start":
  var old := time
  time = minf(time+dt,duration(clip))
  var delta := segment(clip,old,time)
  if time>=duration(clip)-0.000001:
   phase = "move"
   cycle = 0
  delta.y = 0
  return delta
 phase = "move"
 var blend := clampf(intensity-1.0,0,1)
 sprint_weight=move_toward(sprint_weight,1.0 if sprint and not walk else 0.0,dt/maxf(0.01,gait.sprint_blend_in if sprint and not walk else gait.sprint_blend_out))
 var moving_clip := "sprint_civi" if sprint_weight>0.5 else run_clip
 var length := lerpf(lerpf(duration(walk_clip),duration(run_clip),blend),duration("sprint_civi"),sprint_weight)
 var increment := dt/maxf(0.001,length)
 var walk_delta := loop_segment(walk_clip,cycle*duration(walk_clip),(cycle+increment)*duration(walk_clip))
 var run_delta := loop_segment(run_clip,cycle*duration(run_clip),(cycle+increment)*duration(run_clip))
 var sprint_delta := loop_segment("sprint_civi",cycle*duration("sprint_civi"),(cycle+increment)*duration("sprint_civi"))
 var local_delta := walk_delta.lerp(run_delta,blend).lerp(sprint_delta,sprint_weight)*(1.0 if classic_revc else clampf(intensity,0,1))
 cycle = fposmod(cycle+increment,1.0)
 was_sprinting = sprint_weight>0.5
 set_clip(moving_clip if was_sprinting or blend>=0.5 else walk_clip,false)
 time = cycle*duration(clip)
 local_delta.y = 0
 return local_delta

