class_name SkinnedMotionVisual
extends Node3D
## Source animations set absolute local bone rotations on the real DFF hierarchy.
## Planar root displacement belongs to the collision motor; only root height is posed.
var motion: ReferenceMotion
var skeleton: Skeleton3D
var binding := {}
var bound_clip := ""
var sample_us := 0.0
func _ready() -> void:
 skeleton = find_child("Skeleton3D",true,false) as Skeleton3D
func sample_pose() -> void:
 if motion==null or skeleton==null: return
 var selected := motion.preview_clip if not motion.preview_clip.is_empty() else motion.clip
 var at := motion.preview_time if not motion.preview_clip.is_empty() else motion.time
 if not motion.library.has_animation(selected): return
 var animation := motion.library.get_animation(selected)
 if selected!=bound_clip:
  binding.clear()
  for i in range(skeleton.get_bone_count()):
   var path := NodePath("Skeleton3D:"+skeleton.get_bone_name(i))
   binding[i] = [animation.find_track(path,Animation.TYPE_ROTATION_3D),animation.find_track(path,Animation.TYPE_POSITION_3D),animation.find_track(path,Animation.TYPE_SCALE_3D)]
  bound_clip = selected
 var started := Time.get_ticks_usec()
 for i in range(skeleton.get_bone_count()):
  var tracks: Array = binding[i]
  var rest := skeleton.get_bone_rest(i)
  skeleton.set_bone_pose_rotation(i,animation.rotation_track_interpolate(tracks[0],at) if tracks[0]>=0 else rest.basis.get_rotation_quaternion())
  var position := rest.origin
  if tracks[1]>=0:
   var key := animation.position_track_interpolate(tracks[1],at)
   position = Vector3(rest.origin.x,key.y,rest.origin.z) if skeleton.get_bone_name(i)=="Root" else key
  skeleton.set_bone_pose_position(i,position)
  skeleton.set_bone_pose_scale(i,animation.scale_track_interpolate(tracks[2],at) if tracks[2]>=0 else Vector3.ONE)
 skeleton.force_update_all_bone_transforms()
 sample_us = Time.get_ticks_usec()-started
func _process(_dt: float) -> void: sample_pose()
