extends SceneTree
## One compatibility pose from the supplied original ANPK; no other clip is replaced.
func _initialize() -> void:
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/converted/ped_animation_source.json"))
 for clip in data.clips:
  if String(clip.name).to_lower()!="weapon_crouch":continue
  var anim:=Animation.new();anim.resource_name="Original crouch";anim.length=clip.duration
  var metadata:Array[Dictionary]=[]
  for bone in clip.tracks:
   metadata.append({"bone":bone.bone,"bone_id":bone.bone_id,"kind":bone.kind,"sibling_metadata":bone.sibling_metadata})
   if bone.keys.is_empty():continue
   var r:=anim.add_track(Animation.TYPE_ROTATION_3D);anim.track_set_path(r,NodePath("Skeleton3D:"+bone.bone))
   var p:=-1;var s:=-1
   if bone.kind in ["KRT0","KRTS"]:p=anim.add_track(Animation.TYPE_POSITION_3D);anim.track_set_path(p,NodePath("Skeleton3D:"+bone.bone))
   if bone.kind=="KRTS":s=anim.add_track(Animation.TYPE_SCALE_3D);anim.track_set_path(s,NodePath("Skeleton3D:"+bone.bone))
   for key in bone.keys:
    var q:Array=key.rotation;anim.rotation_track_insert_key(r,key.time,Quaternion(q[0],q[1],q[2],q[3]))
    if p>=0:
     var v:Array=key.position;anim.position_track_insert_key(p,key.time,Vector3(v[0],v[1],v[2]))
    if s>=0:
     var v:Array=key.scale;anim.scale_track_insert_key(s,key.time,Vector3(v[0],v[1],v[2]))
  anim.set_meta("ifp_tracks",metadata);anim.set_meta("source_sha256",data.source_sha256)
  var err:=ResourceSaver.save(anim,"res://assets/converted/legacy_crouch.res",ResourceSaver.FLAG_COMPRESS)
  print("LEGACY CROUCH ",anim.length," / ",err);quit(0 if err==OK else 1);return
 push_error("Original crouch clip missing");quit(1)
