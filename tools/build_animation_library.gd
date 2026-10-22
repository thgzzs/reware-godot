extends SceneTree
func _initialize() -> void:
 build.call_deferred()
func build() -> void:
 var version := Engine.get_version_info()
 if version.major!=4 or version.minor!=7 or version.patch!=2 or version.status!="stable":
  push_error("Asset build requires Godot 4.7.2 Stable")
  quit(2)
  return
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/converted/ped_animation_source.json"))
 var lib := AnimationLibrary.new()
 var native_keys := 0
 var native_tracks := 0
 for clip in data.clips:
  var anim := Animation.new()
  anim.resource_name = clip.name
  anim.length = maxf(clip.duration,0.00001)
  # IFP has no universal loop flag; consumers choose loop policy per action.
  anim.loop_mode = Animation.LOOP_NONE
  var track_metadata: Array[Dictionary] = []
  for bone in clip.tracks:
   track_metadata.append({"bone":bone.bone,"bone_id":bone.bone_id,"kind":bone.kind,"sibling_metadata":bone.sibling_metadata})
   if bone.keys.is_empty(): continue
   var rotation_track := anim.add_track(Animation.TYPE_ROTATION_3D)
   anim.track_set_path(rotation_track,NodePath("Skeleton3D:"+bone.bone))
   var position_track := -1
   var scale_track := -1
   if bone.kind in ["KRT0","KRTS"]:
    position_track = anim.add_track(Animation.TYPE_POSITION_3D)
    anim.track_set_path(position_track,NodePath("Skeleton3D:"+bone.bone))
   if bone.kind == "KRTS":
    scale_track = anim.add_track(Animation.TYPE_SCALE_3D)
    anim.track_set_path(scale_track,NodePath("Skeleton3D:"+bone.bone))
   for key in bone.keys:
    var q: Array = key.rotation
    anim.rotation_track_insert_key(rotation_track,key.time,Quaternion(q[0],q[1],q[2],q[3]))
    native_keys += 1
    if position_track>=0:
     var p: Array = key.position
     anim.position_track_insert_key(position_track,key.time,Vector3(p[0],p[1],p[2]))
     native_keys += 1
    if scale_track>=0:
     var s: Array = key.scale
     anim.scale_track_insert_key(scale_track,key.time,Vector3(s[0],s[1],s[2]))
     native_keys += 1
  anim.set_meta("ifp_tracks",track_metadata)
  anim.set_meta("source_sha256",data.source_sha256)
  anim.set_meta("binding_status","unverified until original DFF skeleton/bind pose is available")
  anim.add_marker("clip_end",anim.length)
  native_tracks += anim.get_track_count()
  var added := lib.add_animation(clip.name,anim)
  if added!=OK:
   push_error("Could not add "+clip.name)
   quit(1)
   return
 lib.set_meta("source_format","ANPK")
 lib.set_meta("source_sha256",data.source_sha256)
 lib.set_meta("bone_binding","Skeleton3D:<original bone name>; source bone IDs retained on each clip")
 var err := ResourceSaver.save(lib,"res://assets/converted/ped_library.res",ResourceSaver.FLAG_COMPRESS)
 if err!=OK:
  push_error("Could not save animation library")
  quit(1)
  return
 var source_db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/converted/gameplay_database.json"))
 var db := ImportedGameplayDatabase.new()
 for table in ["ped_stats","weapons","fight_moves","ped_groups","ped_types","handling","special_handling"]:
  var typed: Array[Dictionary] = []
  for row in source_db.get(table,[]): typed.append(row)
  db.set(table,typed)
 if ResourceSaver.save(db,"res://assets/converted/gameplay_database.tres")!=OK:
  push_error("Could not save gameplay Resource")
  quit(1)
  return
 var report := {"clips":lib.get_animation_list().size(),"native_tracks":native_tracks,"native_keys":native_keys,"engine":version.string,"model_binding_verified":false}
 var f := FileAccess.open("res://assets/converted/native_build_report.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report))
 quit()
