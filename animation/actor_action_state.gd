class_name ActorActionState
extends RefCounted
## Per-actor action clocks; no gameplay ownership in the rendered skeleton.
var profile: ActionProfile = preload("res://tuning/actions.tres")
var motion: ReferenceMotion
var aim_weight := 0.0
var aim_pitch := 0.0
var firing_left := 0.0
var firing_duration := 0.16
var reloading := false
var reload_weight := 0.0
var reload_time := 0.0
var life := "alive"
var life_time := 0.0
var life_clip := ""
var weapon_group := "colt45"
var procedural_fire := true
func resolve(candidates: PackedStringArray) -> String:
 if motion==null: return ""
 for candidate in candidates:
  if motion.clip_names.has(candidate.to_lower()): return motion.clip_names[candidate.to_lower()]
 return ""
func fire(interval: float) -> void:
 if life!="alive": return
 firing_duration = maxf(0.08,minf(interval,0.25))
 firing_left = firing_duration
func begin_life(next: String) -> void:
 if life=="dying" or life=="dead": return
 life = next
 life_time = 0
 aim_weight = 0
 firing_left = 0
 reloading = false
 life_clip = resolve(profile.death_clips if next=="dying" else profile.knockdown_clips)
 if motion!=null and not life_clip.is_empty():
  motion.phase = next
  motion.set_clip(life_clip)
  motion.time = 0
func reset() -> void:
 life = "alive"; life_time = 0; life_clip = ""; firing_left = 0; aim_weight = 0; reloading = false; reload_weight = 0
func tick(cmd: GameplayCommand, gun: WeaponController, dt: float) -> void:
 firing_left = maxf(0,firing_left-dt)
 if life!="alive":
  life_time += dt
  var duration := motion.duration(life_clip) if motion!=null else 0.6
  if motion!=null and not life_clip.is_empty():
   motion.phase = life
   motion.set_clip(life_clip,false)
   motion.time = minf(life_time,duration)
  if life=="dying" and life_time>=maxf(0.1,duration): life = "dead"
  return
 reloading = gun.reload_left>0
 reload_weight = move_toward(reload_weight,1.0 if reloading else 0.0,profile.upper_blend_rate*dt)
 reload_time = gun.profile.reload_seconds-gun.reload_left
 weapon_group = gun.profile.animation_group
 var target := 1.0 if cmd.aim or firing_left>0 or reloading else 0.0
 aim_weight = move_toward(aim_weight,target,profile.upper_blend_rate*dt)
func upper_clip() -> String:
 var group_candidate := weapon_group+("_reload" if reloading else "_fire")
 var candidates := PackedStringArray([group_candidate])
 if weapon_group in ["colt45","pistol"]: candidates.append_array(profile.reload_clips if reloading else profile.fire_clips)
 var action := resolve(candidates) if reloading or firing_left>0 else ""
 procedural_fire = action.is_empty()
 return action if not action.is_empty() else resolve(profile.aim_clips)
func upper_time() -> float:
 return reload_time if reloading else firing_duration-firing_left
