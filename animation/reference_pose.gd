class_name ReferencePose
extends Node3D
## A procedural mannequin, NOT the missing DFF skeleton or a verified retarget.
var motion: ReferenceMotion
var skeleton := Skeleton3D.new()
var neutral := {}
var connections: Array[Dictionary] = []
var binding := {}
var bound_clip := ""
var preview_was_active := false
const SHAPE := [
 ["Root","",Vector3.ZERO],["Pelvis","Root",Vector3(0,0,0)],
 ["Spine","Pelvis",Vector3(0,0.20,0)],["Spine1","Spine",Vector3(0,0.20,0)],
 ["Neck","Spine1",Vector3(0,0.18,0)],["Head","Neck",Vector3(0,0.13,0)],
 ["Bip01 L Clavicle","Spine1",Vector3(-0.10,0.13,0)],["L UpperArm","Bip01 L Clavicle",Vector3(-0.10,0,0)],
 ["L Forearm","L UpperArm",Vector3(-0.26,0,0)],["L Hand","L Forearm",Vector3(-0.24,0,0)],["L Finger","L Hand",Vector3(-0.08,0,0)],
 ["Bip01 R Clavicle","Spine1",Vector3(0.10,0.13,0)],["R UpperArm","Bip01 R Clavicle",Vector3(0.10,0,0)],
 ["R Forearm","R UpperArm",Vector3(0.26,0,0)],["R Hand","R Forearm",Vector3(0.24,0,0)],["R Finger","R Hand",Vector3(0.08,0,0)],
 ["L Thigh","Pelvis",Vector3(-0.12,-0.05,0)],["L Calf","L Thigh",Vector3(0,-0.40,0)],["L Foot","L Calf",Vector3(0,-0.39,0)],
 ["R Thigh","Pelvis",Vector3(0.12,-0.05,0)],["R Calf","R Thigh",Vector3(0,-0.40,0)],["R Foot","R Calf",Vector3(0,-0.39,0)]]
func _ready() -> void:
 skeleton.name = "Skeleton3D"
 add_child(skeleton)
 var idle := motion.library.get_animation("IDLE_stance")
 for row in SHAPE:
  var idx := skeleton.add_bone(row[0])
  if not row[1].is_empty(): skeleton.set_bone_parent(idx,skeleton.find_bone(row[1]))
  skeleton.set_bone_rest(idx,Transform3D(Basis.IDENTITY,row[2]))
  skeleton.set_bone_pose_position(idx,row[2])
  var tr := idle.find_track(NodePath("Skeleton3D:"+row[0]),Animation.TYPE_ROTATION_3D)
  neutral[idx] = idle.rotation_track_interpolate(tr,0) if tr>=0 else Quaternion.IDENTITY
  if not row[1].is_empty():
   var mesh := MeshInstance3D.new()
   var tube := CylinderMesh.new()
   tube.height = 1.0
   tube.top_radius = 0.055
   tube.bottom_radius = 0.07
   tube.radial_segments = 8
   mesh.mesh = tube
   mesh.material_override = LabGeometry.material(Color("73ccb9"))
   add_child(mesh)
   connections.append({"from":skeleton.get_bone_parent(idx),"to":idx,"mesh":mesh})
 var head := MeshInstance3D.new()
 var sphere := SphereMesh.new()
 sphere.radius = 0.13
 sphere.height = 0.26
 head.mesh = sphere
 head.material_override = LabGeometry.material(Color("e4c3a4"))
 var attachment := BoneAttachment3D.new()
 skeleton.add_child(attachment)
 attachment.bone_name = "Head"
 attachment.add_child(head)
func _process(_dt: float) -> void:
 if motion==null: return
 var selected := motion.preview_clip if not motion.preview_clip.is_empty() else motion.clip
 var at := motion.preview_time if not motion.preview_clip.is_empty() else motion.time
 if selected!=bound_clip:
  binding.clear()
  var anim := motion.library.get_animation(selected)
  for idx in range(skeleton.get_bone_count()):
   var tr := anim.find_track(NodePath("Skeleton3D:"+skeleton.get_bone_name(idx)),Animation.TYPE_ROTATION_3D)
   if tr>=0: binding[idx] = tr
  bound_clip = selected
 var animation := motion.library.get_animation(selected)
 for idx in range(skeleton.get_bone_count()):
  var rotation := Quaternion.IDENTITY
  if binding.has(idx): rotation = neutral[idx].inverse()*animation.rotation_track_interpolate(binding[idx],at)
  skeleton.set_bone_pose_rotation(idx,rotation)
 skeleton.force_update_all_bone_transforms()
 for link in connections:
  var a := skeleton.get_bone_global_pose(link.from).origin
  var b := skeleton.get_bone_global_pose(link.to).origin
  var delta := b-a
  link.mesh.position = (a+b)*0.5
  if delta.length()>0.001:
   link.mesh.quaternion = Quaternion(Vector3.UP,delta.normalized())
   link.mesh.scale = Vector3(1,delta.length(),1)
