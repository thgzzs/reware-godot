class_name SkinnedMotionVisual
extends Node3D
## Locomotion phase blend -> action crossfade -> masked upper body -> aim IK.
## The collision motor alone consumes planar root motion.
var motion: ReferenceMotion
var actions: ActorActionState
var rig_profile: AnimationRigProfile
var skeleton: Skeleton3D
var tracks := {}
var signature := ""
var transition_time := 0.0
var from_positions: Array[Vector3] = []
var from_rotations: Array[Quaternion] = []
var from_scales: Array[Vector3] = []
var upper_mask: Array[int] = []
var melee_mask: Array[int] = []
var melee_kick_mask: Array[int] = []
var upper_signature := ""
var upper_transition := 0.0
var upper_from: Array[Quaternion] = []
var base_rotations: Array[Quaternion] = []
var upper_rotations: Array[Quaternion] = []
var sample_us := 0.0
var rest_position := Vector3.ZERO
var ground_offset := 0.0
var floor_minimum := {}
func _ready() -> void:
 rest_position = position
 skeleton = find_child("Skeleton3D",true,false) as Skeleton3D
 if skeleton!=null:
  for i in range(skeleton.get_bone_count()):
   from_positions.append(skeleton.get_bone_pose_position(i))
   from_rotations.append(skeleton.get_bone_pose_rotation(i))
   from_scales.append(skeleton.get_bone_pose_scale(i))
   upper_from.append(skeleton.get_bone_pose_rotation(i))
   base_rotations.append(skeleton.get_bone_pose_rotation(i))
   upper_rotations.append(skeleton.get_bone_pose_rotation(i))
   if actions!=null and actions.profile.upper_bones.has(skeleton.get_bone_name(i)): upper_mask.append(i)
   if i in upper_mask or skeleton.get_bone_name(i)=="Spine":melee_mask.append(i)
   if actions!=null and actions.profile.mobile_kick_bones.has(skeleton.get_bone_name(i)):melee_kick_mask.append(i)
func binding(name: String) -> Array:
 if tracks.has(name): return tracks[name]
 var animation := motion.library.get_animation(name)
 var bindings := AnimationRigBinding.build(animation,skeleton,rig_profile)
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
   from_rotations[i] = base_rotations[i]
   from_scales[i] = skeleton.get_bone_pose_scale(i)
  signature = next
  transition_time = 0
 transition_time += dt
 var duration := actions.profile.blend_seconds if actions!=null else 0.16
 if motion.clip=="JUMP_launch": duration = minf(duration,0.04)
 var alpha := smoothstep(0,1,clampf(transition_time/maxf(0.001,duration),0,1))
 if not motion.preview_clip.is_empty(): alpha = 1
 var started := Time.get_ticks_usec()
 var upper := actions.upper_clip() if actions!=null and actions.life=="alive" else ""
 if upper!=upper_signature:
  upper_signature = upper
  upper_transition = 0
  for i in range(skeleton.get_bone_count()): upper_from[i] = upper_rotations[i]
 upper_transition += dt
 var upper_alpha := smoothstep(0,1,clampf(upper_transition/maxf(0.001,duration),0,1))
 var upper_at := 0.0
 if not upper.is_empty():
  if actions.reloading or actions.firing_left>0:upper_at=minf(actions.upper_time(),motion.duration(upper))
  elif actions.native_aim_hold:upper_at=clampf(actions.fire_frame_seconds-0.03,0,motion.duration(upper))
  else:upper_at=fposmod(motion.time,maxf(0.001,motion.duration(upper)))
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
  base_rotations[i] = q
  if not upper.is_empty() and actions.includes_upper_bone(skeleton.get_bone_name(i)) and motion.preview_clip.is_empty():
   q = q.slerp(upper_from[i].slerp(rotation_at(upper,upper_at,i),upper_alpha),actions.aim_weight)
  if actions!=null and actions.life=="alive" and actions.melee_weight>0 and motion.preview_clip.is_empty() and (i in melee_mask or (actions.melee_is_kick and i in melee_kick_mask)) and not actions.melee_clip.is_empty():
   q=q.slerp(rotation_at(actions.melee_clip,minf(actions.melee_time,motion.duration(actions.melee_clip)),i),actions.melee_weight)
  upper_rotations[i] = q
  if actions!=null and actions.life=="alive" and not actions.melee_active and actions.reaction_left>0 and skeleton.get_bone_name(i) in ["Spine","Spine1","Neck","Head"] and motion.preview_clip.is_empty():
   var at := actions.reaction_duration-actions.reaction_left
   q = q.slerp(rotation_at(actions.reaction_clip,at,i),minf(1,actions.reaction_left/maxf(0.001,actions.reaction_duration))*0.45)
  skeleton.set_bone_pose_position(i,p)
  skeleton.set_bone_pose_rotation(i,q)
  skeleton.set_bone_pose_scale(i,s)
 skeleton.force_update_all_bone_transforms()
 if actions!=null and actions.life=="alive" and motion.preview_clip.is_empty() and actions.aim_weight>0 and actions.upper_allowed:
  aim_arms()
 settle_reaction_pose(dt)
 sample_us = Time.get_ticks_usec()-started
func skin_minimum_y() -> float:
 var minimum := INF
 for mesh in find_children("*","MeshInstance3D",true,false):
  if mesh.skin==null: continue
  for surface in range(mesh.mesh.get_surface_count()):
   var arrays: Array = mesh.mesh.surface_get_arrays(surface)
   var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
   var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
   if weights.size()!=vertices.size()*4: continue
   for i in range(vertices.size()):
    var vertex := Vector3.ZERO
    for j in range(4):
     if weights[i*4+j]<=0: continue
     var bind: int = bones[i*4+j]
     vertex += skeleton.get_bone_global_pose(mesh.skin.get_bind_bone(bind))*mesh.skin.get_bind_pose(bind)*vertices[i]*weights[i*4+j]
    minimum = minf(minimum,vertex.y)
 return minimum
func settle_reaction_pose(dt: float) -> void:
 if actions==null or actions.life=="alive" or not motion.preview_clip.is_empty():
  ground_offset = 0
  position = rest_position
  return
 var target := 0.0
 var actor := get_parent().get_parent() as CharacterMotor
 if actor!=null and actor.reaction_body.active:
  ground_offset = 0
  position = rest_position
  return
 if actor!=null and actor.grounded and actions.life in ["dead","down"] and motion.time>=motion.duration(motion.clip)-0.001:
  if not floor_minimum.has(motion.clip): floor_minimum[motion.clip] = skin_minimum_y()
  var minimum: float = floor_minimum[motion.clip]
  var ray := PhysicsRayQueryParameters3D.create(actor.global_position,actor.global_position-Vector3.UP*2,1,[actor.get_rid()])
  var floor_hit := get_world_3d().direct_space_state.intersect_ray(ray)
  if is_finite(minimum) and not floor_hit.is_empty():
   target = clampf(floor_hit.position.y+actions.profile.reaction_floor_clearance-(actor.global_position.y+rest_position.y+minimum),0,actions.profile.reaction_max_lift)
 ground_offset = move_toward(ground_offset,target,actions.profile.reaction_settle_speed*dt)
 position = rest_position+Vector3.UP*ground_offset
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
 if (actions.reloading or actions.native_fire_owns_upper) and not actions.procedural_fire: return
 var upper := skeleton.find_bone("R UpperArm")
 var forearm := skeleton.find_bone("R Forearm")
 var hand := skeleton.find_bone("R Hand")
 if mini(upper,mini(forearm,hand))<0: return
 var direction := Vector3(0,-sin(actions.aim_pitch),-cos(actions.aim_pitch))
 if actions.has_aim_target:
  direction = (skeleton.to_local(actions.aim_target)-skeleton.get_bone_global_pose(hand).origin).normalized()
  var limit := 1.65 if actions.hip_firing else 1.15
  var yaw := clampf(atan2(direction.x,-direction.z),-limit,limit)
  direction = Vector3(sin(yaw)*Vector2(direction.x,direction.z).length(),direction.y,-cos(yaw)*Vector2(direction.x,direction.z).length()).normalized()
 var cfg := actions.weapon_pose
 var recoil := actions.firing_left/maxf(0.001,actions.firing_duration)*cfg.recoil_lift
 var target := skeleton.get_bone_global_pose(upper).origin+direction*cfg.reach+cfg.grip_offset+Vector3.UP*recoil
 var reload_phase := clampf(actions.reload_time/maxf(0.01,actions.reload_duration),0,1)
 var reload_target := cfg.reload_grip+Vector3(0,-sin(reload_phase*PI)*cfg.reload_drop,0.05*sin(reload_phase*TAU))
 target = target.lerp(reload_target,actions.reload_weight)
 for iteration in range(cfg.solver_passes):
  turn_joint(forearm,hand,target,actions.aim_weight)
  turn_joint(upper,hand,target,actions.aim_weight)
 if actions.reload_weight<0.99:
  var pose := skeleton.get_bone_global_pose(hand)
  if actions.has_aim_target:
   direction = (skeleton.to_local(actions.aim_target)-pose.origin).normalized()
   var limit := 1.65 if actions.hip_firing else 1.15
   var yaw := clampf(atan2(direction.x,-direction.z),-limit,limit)
   direction = Vector3(sin(yaw)*Vector2(direction.x,direction.z).length(),direction.y,-cos(yaw)*Vector2(direction.x,direction.z).length()).normalized()
  var delta := Quaternion(pose.basis.x.normalized(),direction)
  var parent := skeleton.get_bone_parent(hand)
  var local := skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion().inverse()*delta*pose.basis.get_rotation_quaternion()
  skeleton.set_bone_pose_rotation(hand,skeleton.get_bone_pose_rotation(hand).slerp(local,actions.aim_weight*(1.0-actions.reload_weight)))
  skeleton.force_update_all_bone_transforms()
 var left_hand := skeleton.find_bone("L Hand")
 var left_forearm := skeleton.find_bone("L Forearm")
 var left_upper := skeleton.find_bone("L UpperArm")
 if (actions.reloading or actions.weapon_two_handed) and mini(left_hand,mini(left_forearm,left_upper))>=0:
  var support := skeleton.get_bone_global_pose(hand).origin+(cfg.magazine_offset+Vector3.DOWN*sin(reload_phase*PI)*cfg.magazine_travel if actions.reloading else direction*cfg.support_reach+Vector3.DOWN*cfg.support_drop)
  for iteration in range(cfg.solver_passes):
   turn_joint(left_forearm,left_hand,support,actions.aim_weight)
   turn_joint(left_upper,left_hand,support,actions.aim_weight)
func _process(dt: float) -> void:
 var actor := get_parent().get_parent() as CharacterMotor
 if actor!=null and actor.reaction_body.active: return
 sample_pose(dt)
