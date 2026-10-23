extends SceneTree
## Preserve source tracks; only coincident times are explicitly coalesced last-key-wins.
var source_keys:=0
var native_keys:=0
var native_tracks:=0
func _initialize() -> void:build.call_deferred()
func make_animation(clip:Dictionary) -> Animation:
 var anim:=Animation.new()
 anim.resource_name=clip.name
 anim.length=maxf(clip.duration,0.00001)
 var metadata:Array[Dictionary]=[]
 for bone in clip.tracks:
  metadata.append({"bone":bone.bone,"bone_id":bone.bone_id,"kind":bone.kind,"sibling_metadata":bone.sibling_metadata})
  if bone.keys.is_empty():continue
  var path:=NodePath("Skeleton3D:"+bone.bone)
  var rotation:=anim.add_track(Animation.TYPE_ROTATION_3D)
  anim.track_set_path(rotation,path)
  var position:=-1
  var scale:=-1
  if bone.kind in ["KRT0","KRTS"]:
   position=anim.add_track(Animation.TYPE_POSITION_3D);anim.track_set_path(position,path)
  if bone.kind=="KRTS":
   scale=anim.add_track(Animation.TYPE_SCALE_3D);anim.track_set_path(scale,path)
  var unique:Array[Dictionary]=[]
  for key in bone.keys:
   if not unique.is_empty() and float(unique[-1].time)==float(key.time):unique[-1]=key
   else:unique.append(key)
  source_keys+=bone.keys.size()*(1+(1 if position>=0 else 0)+(1 if scale>=0 else 0))
  for key in unique:
   var q:Array=key.rotation
   anim.rotation_track_insert_key(rotation,key.time,Quaternion(q[0],q[1],q[2],q[3]))
   if position>=0:
    var p:Array=key.position
    anim.position_track_insert_key(position,key.time,Vector3(p[0],p[1],p[2]))
   if scale>=0:
    var s:Array=key.scale
    anim.scale_track_insert_key(scale,key.time,Vector3(s[0],s[1],s[2]))
 anim.set_meta("ifp_tracks",metadata)
 anim.set_meta("source_sha256",clip.source_sha256)
 anim.set_meta("source_clip",clip.source_clip)
 anim.set_meta("binding_policy","original model bone IDs, then normalized names; unbound extra face tracks retained")
 native_tracks+=anim.get_track_count()
 for track in range(anim.get_track_count()):native_keys+=anim.track_get_key_count(track)
 return anim
func build() -> void:
 var version:=Engine.get_version_info()
 if version.major!=4 or version.minor!=7 or version.patch!=2 or version.status!="stable":quit(2);return
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/converted/stories_animation_source.json"))
 var library:=AnimationLibrary.new()
 for clip in source.clips:
  if library.add_animation(clip.name,make_animation(clip))!=OK:quit(1);return
 for alias in source.aliases:
  if library.add_animation(alias,library.get_animation(source.aliases[alias]))!=OK:quit(1);return
 library.set_meta("source_sha256",source.source_sha256)
 library.set_meta("source_format","ANPK")
 if ResourceSaver.save(library,"res://assets/converted/ped_library.res",ResourceSaver.FLAG_COMPRESS)!=OK:quit(1);return
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/converted/gameplay_database.json"))
 var db:=ImportedGameplayDatabase.new()
 for table in ["ped_stats","weapons","fight_moves","ped_groups","ped_types","handling","special_handling"]:
  var rows:Array[Dictionary]=[]
  for row in data.get(table,[]):rows.append(row)
  db.set(table,rows)
 if ResourceSaver.save(db,"res://assets/converted/gameplay_database.tres")!=OK:quit(1);return
 var report:={"clips":source.clips.size(),"active_aliases":source.aliases.size(),"native_entries":library.get_animation_list().size(),"source_keys":source_keys,"native_keys":native_keys,"native_tracks":native_tracks,"coincident_channel_keys_coalesced":source_keys-native_keys,"engine":version.string}
 FileAccess.open("res://assets/converted/native_stories_build_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report))
 quit()
