class_name SkinnedMotionVisual
extends Node3D
## Locomotion phase blend -> action crossfade -> masked upper body -> aim IK.
## The collision motor alone consumes planar root motion.
var motion: ReferenceMotion
var actions: ActorActionState
var skeleton: Skeleton3D
var tracks := {}
var signature := ""
var transition_time := 0.0
var from_positions: Array[Vector3] = []
var from_rotations: Array[Quaternion] = []
var from_scales: Array[Vector3] = []
var upper_mask: Array[int] = []
var upper_signature := ""
var upper_transition := 0.0
var upper_from: Array[Quaternion] = []
var sample_us := 0.0
func _ready() -> void:
 skeleton = find_child("Skeleton3D",true,false) as Skeleton3D
 if skeleton!=null:
  for i in range(skeleton.get_bone_count()):
   from_positions.append(skeleton.get_bone_pose_position(i))
   from_rotations.append(skeleton.get_bone_pose_rotation(i))
   from_scales.append(skeleton.get_bone_pose_scale(i))
   upper_from.append(skeleton.get_bone_pose_rotation(i))
   if actions!=null and actions.profile.upper_bones.has(skeleton.get_bone_name(i)): upper_mask.append(i)
func binding(name: String) -> Array:
 if tracks.has(name): return tracks[name]
 var bindings := []
 var animation := motion.library.get_animation(name)
 for i in range(skeleton.get_bone_count()):
  var path := NodePath("Skeleton3D:"+skeleton.get_bone_name(i))
  bindings.append([animation.find_track(path,Animation.TYPE_ROTATION_3D),animation.find_track(path,Animation.TYPE_POSITION_3D),animation.find_track(path,Animation.TYPE_SCALE_3D)])
 tracks[name] = bindings
 return bindings
func rotation_at(name: String, at: float, bone: int) -> Quaternion:
 var index: int = binding(name)[bone][0]
 return motion.library.get_animation(name).rotation_track_interpolate(index,at) if index>=0 else skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
func position_at(name: String, at: float, bone: int) -> Vector3:
 var rest := skeleton.get_bone_rest(bone).origin
 var index: int = binding(name)[bone][1]
 if index<0: return rest
 var key := motion.library.get_animation(name).position_track_interpolate(index,at)
 return Vector3(rest.x,key.y,rest.z) if skeleton.get_bone_name(bone)=="Root" else key
func scale_at(name: String, at: float, bone: int) -> Vector3:
 var index: int = binding(name)[bone][2]
 return motion.library.get_animation(name).scale_track_interpolate(index,at) if index>=0 else Vector3.ONE
func sample_pose(dt: float = 1.0/60.0) -> void:
 if motion==null or skeleton==null: return
 var layers := motion.pose_layers()
 var next := ""
 for layer in layers: next += layer.clip+"|"
 if next!=signature:
  for i in range(skeleton.get_bone_count()):
   from_positions[i] = skeleton.get_bone_pose_position(i)
   from_rotations[i] = skeleton.get_bone_pose_rotation(i)
   from_scales[i] = skeleton.get_bone_pose_scale(i)
  signature = next
  transition_time = 0
 transition_time += dt
 var duration := actions.profile.blend_seconds if actions!=null else 0.16
 var alpha := smoothstep(0,1,clampf(transition_time/maxf(0.001,duration),0,1))
 if not motion.preview_clip.is_empty(): alpha = 1
 var started := Time.get_ticks_usec()
 var upper := actions.upper_clip() if actions!=null and actions.life=="alive" else ""
 if upper!=upper_signature:
  upper_signature = upper
  upper_transition = 0
  for i in range(skeleton.get_bone_count()): upper_from[i] = skeleton.get_bone_pose_rotation(i)
 upper_transition += dt
 var upper_alpha := smoothstep(0,1,clampf(upper_transition/maxf(0.001,duration),0,1))
 var upper_at := 0.0
 if not upper.is_empty():
  upper_at = minf(actions.upper_time(),motion.duration(upper)) if actions.reloading or actions.firing_left>0 else fposmod(motion.time,maxf(0.001,motion.duration(upper)))
 for i in range(skeleton.get_bone_count()):
  var p := skeleton.get_bone_rest(i).origin
  var q := skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
  var s := Vector3.ONE
  var accumulated := 0.0
  for layer in layers:
   if layer.weight<=0 or not motion.library.has_animation(layer.clip): continue
   var weight: float = layer.weight/(accumulated+layer.weight)
   p = p.lerp(position_at(layer.clip,layer.time,i),weight)
   q = q.slerp(rotation_at(layer.clip,layer.time,i),weight)
   s = s.lerp(scale_at(layer.clip,layer.time,i),weight)
   accumulated += layer.weight
  p = from_positions[i].lerp(p,alpha)
  q = from_rotations[i].slerp(q,alpha)
  s = from_scales[i].lerp(s,alpha)
  if not upper.is_empty() and i in upper_mask and motion.preview_clip.is_empty():
   q = q.slerp(upper_from[i].slerp(rotation_at(upper,upper_at,i),upper_alpha),actions.aim_weight)
  skeleton.set_bone_pose_position(i,p)
  skeleton.set_bone_pose_rotation(i,q)
  skeleton.set_bone_pose_scale(i,s)
 skeleton.force_update_all_bone_transforms()
 if actions!=null and actions.life=="alive" and motion.preview_clip.is_empty() and actions.aim_weight>0:
  aim_arms()
 sample_us = Time.get_ticks_usec()-started
func turn_joint(joint: int, end: int, target: Vector3, weight: float) -> void:
 var origin := skeleton.get_bone_global_pose(joint).origin
 var direction := skeleton.get_bone_global_pose(end).origin-origin
 var desired := target-origin
 if direction.length_squared()<0.000001 or desired.length_squared()<0.000001: return
 var global_rotation := skeleton.get_bone_global_pose(joint).basis.get_rotation_quaternion()
 var delta := Quaternion(direction.normalized(),desired.normalized())
 var parent := skeleton.get_bone_parent(joint)
 var parent_rotation := skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent>=0 else Quaternion.IDENTITY
 var next := parent_rotation.inverse()*delta*global_rotation
 skeleton.set_bone_pose_rotation(joint,skeleton.get_bone_pose_rotation(joint).slerp(next,weight))
 skeleton.force_update_all_bone_transforms()
func aim_arms() -> void:
 var upper := skeleton.find_bone("R UpperArm")
 var forearm := skeleton.find_bone("R Forearm")
 var hand := skeleton.find_bone("R Hand")
 if mini(upper,mini(forearm,hand))<0: return
 var direction := Vector3(0,-sin(actions.aim_pitch),-cos(actions.aim_pitch))
 var recoil := actions.firing_left/maxf(0.001,actions.firing_duration)*0.055
 var target := skeleton.get_bone_global_pose(upper).origin+direction*0.53+Vector3(0.02,recoil,0)
 target = target.lerp(Vector3(0.10,0.05,-0.30),actions.reload_weight)
 for iteration in range(3):
  turn_joint(forearm,hand,target,actions.aim_weight)
  turn_joint(upper,hand,target,actions.aim_weight)
 if actions.reload_weight<0.99:
  var pose := skeleton.get_bone_global_pose(hand)
  var delta := Quaternion(pose.basis.x.normalized(),direction)
  var parent := skeleton.get_bone_parent(hand)
  var local := skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion().inverse()*delta*pose.basis.get_rotation_quaternion()
  skeleton.set_bone_pose_rotation(hand,skeleton.get_bone_pose_rotation(hand).slerp(local,actions.aim_weight*(1.0-actions.reload_weight)))
  skeleton.force_update_all_bone_transforms()
 var left_hand := skeleton.find_bone("L Hand")
 var left_forearm := skeleton.find_bone("L Forearm")
 var left_upper := skeleton.find_bone("L UpperArm")
 if (actions.reloading or actions.weapon_group in ["rifle","riflebad","shotgun","m4","ruger"]) and mini(left_hand,mini(left_forearm,left_upper))>=0:
  var support := skeleton.get_bone_global_pose(hand).origin+(Vector3(-0.03,-0.04,0) if actions.reloading else direction*0.20+Vector3(0,-0.035,0))
  for iteration in range(2):
   turn_joint(left_forearm,left_hand,support,actions.aim_weight)
   turn_joint(left_upper,left_hand,support,actions.aim_weight)
func _process(dt: float) -> void: sample_pose(dt)
