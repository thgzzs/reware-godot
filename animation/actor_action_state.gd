class_name ActorActionState
extends RefCounted
## Per-actor action clocks; no gameplay ownership in the rendered skeleton.
var weapon_pose: WeaponPoseProfile = preload("res://tuning/weapon_pose.tres")
var profile: ActionProfile = preload("res://tuning/actions.tres")
var motion: ReferenceMotion
var aim_weight := 0.0
var aim_pitch := 0.0
var aim_target := Vector3.ZERO
var has_aim_target := false
var upper_allowed := true
var firing_left := 0.0
var firing_duration := 0.16
var reloading := false
var reload_weight := 0.0
var reload_time := 0.0
var reload_duration := 1.0
var life := "alive"
var life_time := 0.0
var life_clip := ""
var weapon_group := "colt45"
var weapon_two_handed := false
var hip_firing := false
var preparing_fire:=false
var fire_frame_seconds := 0.0
var procedural_fire := true
var native_fire_owns_upper := false
var native_aim_hold := false
var standing_hold_clip := ""
var standing_hold_weight := 0.0
var standing_hold_time := 0.0
var crouched := false
var next_death := ""
var reaction_clip := ""
var reaction_left := 0.0
var reaction_duration := 0.0
var melee_clip := ""
var melee_time := 0.0
var melee_active := false
var melee_mobile := false
var melee_is_kick := false
var melee_weight := 0.0
var reaction_time := 0.0
var reaction_previous_time := 0.0
var reaction_heading := 0.0
var reaction_spatial := false
var floor_hit_clip := ""
var floor_hit_time := 0.0
var floor_hit_left := 0.0
func full_body_busy() -> bool: return melee_active
func choose_reaction(event: DamageEvent, facing: float, origin: Vector3) -> void:
 var local := Basis(Vector3.UP,facing).inverse()*(-event.direction)
 if Vector2(local.x,local.z).length_squared()<0.0001: local = Vector3.FORWARD
 var angle := atan2(local.x,-local.z)
 var side := "front"
 if absf(angle)>PI*0.75: side = "back"
 elif angle< -PI*0.25: side = "L"
 elif angle>PI*0.25: side = "R"
 var deaths := {"front":"KO_shot_front","back":"KO_skid_back","L":"KO_spin_L","R":"KO_spin_R"}
 next_death = resolve(PackedStringArray([deaths[side]]))
 if event.kind=="bullet" and (event.part=="head" or (not crouched and event.point.y-origin.y>0.55)):
  next_death = resolve(PackedStringArray(["KO_shot_face",deaths[side]]))
 reaction_clip = resolve(PackedStringArray(["HIT_"+side,"HIT_front"]))
func react(event: DamageEvent, heading:=0.0, spatial:=false) -> void:
 if life!="alive" or event.kind=="vehicle" or motion==null: return
 reaction_duration = minf(profile.hit_max_seconds,motion.duration(reaction_clip)/profile.hit_playback_rate)
 reaction_left = reaction_duration
 reaction_time=0
 reaction_previous_time=0;reaction_heading=heading;reaction_spatial=spatial
func spatial_hit() -> bool:
 return reaction_spatial and (reaction_left>0 or reaction_time>reaction_previous_time)
func reaction_at() -> float:
 return reaction_time/maxf(0.001,reaction_duration)*motion.duration(reaction_clip) if motion!=null else 0.0
func reaction_travel() -> Vector3:
 if not spatial_hit() or motion==null:return Vector3.ZERO
 var previous:=reaction_previous_time/maxf(0.001,reaction_duration)*motion.duration(reaction_clip)
 var delta:=motion.segment(reaction_clip,previous,reaction_at());delta.y=0
 return delta
func react_on_floor(face_down:bool) -> void:
 floor_hit_clip=resolve(PackedStringArray(["FLOOR_hit_f","FLOOR_hit"]) if face_down else PackedStringArray(["FLOOR_hit","FLOOR_hit_f"]))
 floor_hit_time=0
 floor_hit_left=motion.duration(floor_hit_clip) if motion!=null else 0
func includes_upper_bone(name: String) -> bool:
 if not profile.upper_bones.has(name): return false
 if (name.begins_with("L ") or " L Clavicle" in name) and not weapon_two_handed and not reloading: return false
 return true
func resolve(candidates: PackedStringArray) -> String:
 if motion==null: return ""
 for candidate in candidates:
  if motion.clip_names.has(candidate.to_lower()): return motion.clip_names[candidate.to_lower()]
 return ""
func fire(interval: float, native_recovery:=0.0) -> void:
 if life!="alive": return
 firing_duration = native_recovery if native_recovery>0 else maxf(0.08,minf(interval,0.25))
 firing_left = firing_duration
func begin_life(next: String) -> void:
 if life=="dying" or life=="dead": return
 life = next
 if motion!=null:motion.vehicle_layers.clear()
 life_time = 0
 aim_weight = 0
 standing_hold_weight=0
 firing_left = 0
 reloading = false
 reload_weight=0;preparing_fire=false;reaction_left=0;reaction_spatial=false
 melee_active=false;melee_weight=0;floor_hit_left=0
 life_clip = next_death if next=="dying" and not next_death.is_empty() else resolve(profile.death_clips if next=="dying" else profile.knockdown_clips)
 if motion!=null and not life_clip.is_empty():
  motion.phase = next
  motion.set_clip(life_clip)
  motion.time = 0
func reset() -> void:
 next_death = ""; reaction_left = 0; melee_active = false; melee_clip = ""; melee_mobile=false; melee_weight=0; melee_is_kick=false
 preparing_fire=false
 standing_hold_clip="";standing_hold_weight=0;standing_hold_time=0
 life = "alive"; life_time = 0; life_clip = ""; firing_left = 0; aim_weight = 0; reloading = false; reload_weight = 0;floor_hit_left=0;floor_hit_time=0;reaction_time=0;reaction_previous_time=0;reaction_spatial=false
func tick(cmd: GameplayCommand, gun: WeaponController, dt: float) -> void:
 melee_weight = move_toward(melee_weight,1.0 if melee_active and melee_mobile else 0.0,profile.upper_blend_rate*dt)
 reaction_previous_time=reaction_time
 if reaction_left>0:reaction_time=minf(reaction_duration,reaction_time+dt)
 reaction_left = maxf(0,reaction_left-dt)
 floor_hit_left=maxf(0,floor_hit_left-dt)
 if floor_hit_left>0:floor_hit_time+=dt
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
 native_fire_owns_upper=gun.profile.native_fire_recovery>0 and firing_left>0
 reloading = gun.reload_left>0 and not native_fire_owns_upper
 reload_weight = move_toward(reload_weight,1.0 if reloading else 0.0,profile.upper_blend_rate*dt)
 reload_duration = gun.profile.reload_seconds
 reload_time = reload_duration-gun.reload_left
 weapon_group = gun.profile.animation_group
 weapon_two_handed = gun.profile.two_handed
 hip_firing = cmd.fire and not cmd.aim
 preparing_fire=cmd.fire and firing_left<=0 and gun.profile.kind!="melee"
 fire_frame_seconds = gun.profile.fire_frame_seconds
 weapon_pose = gun.profile.pose
 upper_allowed = gun.profile.kind!="melee" and not melee_active and (motion==null or motion.phase in ["idle","start","move","stop"] or crouched)
 if cmd.sprint and not (cmd.aim or cmd.fire or reloading) and cmd.move.length_squared()>0.01: upper_allowed = false
 if reaction_left>0:upper_allowed=false
 var carry:=resolve(weapon_pose.standing_hold_clips)
 if carry!=standing_hold_clip:standing_hold_clip=carry;standing_hold_time=0
 var carrying:=not carry.is_empty() and upper_allowed and not crouched and (motion==null or motion.phase=="idle")
 var carry_target:float=gun.equip_action.pose_weight() if carrying else 0.0
 standing_hold_weight=move_toward(standing_hold_weight,carry_target,dt/maxf(0.001,weapon_pose.standing_hold_blend_seconds))
 if not carry.is_empty() and standing_hold_weight>0:standing_hold_time=fposmod(standing_hold_time+dt,maxf(0.001,motion.duration(carry)))
 var target := 1.0 if upper_allowed and (cmd.aim or cmd.fire or firing_left>0 or reloading) else 0.0
 target*=gun.equip_action.pose_weight()
 aim_weight = move_toward(aim_weight,target,profile.upper_blend_rate*dt)
func upper_clip() -> String:
 if not upper_allowed: return ""
 var suffix := "_crouchreload" if reloading and crouched else ("_crouchfire" if crouched else ("_reload" if reloading else "_fire"))
 var group_candidate := weapon_group+suffix
 var candidates := PackedStringArray([group_candidate,weapon_group+("_crouchload" if crouched else "_load") if reloading else weapon_group+"_fire",weapon_group+("_reload" if reloading else "_fire")])
 if weapon_group in ["colt45","pistol"]: candidates.append_array(profile.reload_clips if reloading else profile.fire_clips)
 var action := resolve(candidates) if reloading or firing_left>0 else ""
 procedural_fire = action.is_empty()
 native_aim_hold=false
 if not action.is_empty():return action
 # A missing reload must use the procedural reload fallback, never sample a
 # firing clip as if it were a reload/standing hold.
 if reloading:return ""
 if weapon_two_handed or preparing_fire:
  var hold:=resolve(PackedStringArray([weapon_group+"_crouchfire" if crouched else weapon_group+"_fire"]))
  if not hold.is_empty():native_aim_hold=true;return hold
 return resolve(profile.aim_clips)
func upper_time() -> float:
 return reload_time if reloading else fire_frame_seconds+firing_duration-firing_left
