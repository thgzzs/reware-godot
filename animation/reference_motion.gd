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
var was_sprinting := false
var walk_clip := "WALK_player"
var run_clip := "run_player"
var preview_clip := ""
var preview_time := 0.0
var preview_playing := true
var roots := {}
func _init(source: AnimationLibrary) -> void:
 library = source
 for name in library.get_animation_list():
  var a := library.get_animation(name)
  roots[name] = a.find_track(NodePath("Skeleton3D:Root"),Animation.TYPE_POSITION_3D)
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
 var start := fposmod(a,length)
 var finish := start+(b-a)
 if finish<=length: return segment(name,start,finish)
 return segment(name,start,length)+segment(name,0,finish-length)
func force_action(name: String, dt: float) -> void:
 if clip!=name: set_clip(name)
 else: time = minf(time+dt,duration(name))
func step(amount: float, sprint: bool, walk: bool, dt: float) -> Vector3:
 heading_locked = false
 if not preview_clip.is_empty():
  if preview_playing: preview_time = fposmod(preview_time+dt,maxf(0.001,duration(preview_clip)))
  return Vector3.ZERO
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
  phase = "idle"
  intensity = 0
  set_clip("IDLE_stance")
  time = fposmod(time+dt,duration(clip))
  return Vector3.ZERO
 intensity = move_toward(intensity,amount*(1.0 if walk else 2.0),3.5*dt)
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
 var moving_clip := "sprint_civi" if sprint and not walk else run_clip
 var length := duration(moving_clip) if sprint and not walk else lerpf(duration(walk_clip),duration(run_clip),blend)
 var increment := dt/maxf(0.001,length)
 var local_delta := loop_segment(moving_clip,cycle*duration(moving_clip),(cycle+increment)*duration(moving_clip))
 if not sprint or walk:
  var walk_delta := loop_segment(walk_clip,cycle*duration(walk_clip),(cycle+increment)*duration(walk_clip))
  local_delta = walk_delta.lerp(local_delta,blend)
 cycle = fposmod(cycle+increment,1.0)
 was_sprinting = sprint and not walk
 set_clip(moving_clip if was_sprinting or blend>=0.5 else walk_clip,false)
 time = cycle*duration(clip)
 local_delta.y = 0
 return local_delta
