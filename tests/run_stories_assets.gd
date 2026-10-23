extends SceneTree
var results:Array[Dictionary]=[]
var failures:=0
func check(label:String, condition:bool, measured:Variant=null) -> void:
 results.append({"name":label,"passed":condition,"measured":measured})
 if not condition:failures+=1
 print("PASS " if condition else "FAIL ",label," ",measured)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/converted/stories_animation_source.json"))
 var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/converted/stories_catalog.json"))
 var library:AnimationLibrary=load("res://assets/converted/ped_library.res")
 check("all 44 supplied IFP blocks retained",catalog.blocks.size()==44,catalog.blocks.size())
 check("all 781 source clips retained without name collisions",source.clips.size()==781,source.clips.size())
 check("native catalog includes every source clip and 387 gameplay aliases",library.get_animation_list().size()==1168,library.get_animation_list().size())
 var keys:=0
 var channels:=0
 var mismatches:=0
 var max_error:=0.0
 var missing_tracks:=0
 for clip in source.clips:
  if not library.has_animation(clip.name):mismatches+=1;continue
  var native:=library.get_animation(clip.name)
  if absf(native.length-maxf(0.00001,clip.duration))>0.00001:mismatches+=1
  var cursor:=0
  for bone in clip.tracks:
   var path:=NodePath("Skeleton3D:"+bone.bone)
   if bone.keys.is_empty():continue
   var rotation:=cursor;cursor+=1
   var position:=-1
   var scale:=-1
   if bone.kind in ["KRT0","KRTS"]:position=cursor;cursor+=1
   if bone.kind=="KRTS":scale=cursor;cursor+=1
   if native.track_get_path(rotation)!=path:mismatches+=1
   if rotation<0:missing_tracks+=1;continue
   channels+=1
   if bone.kind in ["KRT0","KRTS"]:channels+=1
   if bone.kind=="KRTS":channels+=1
   var unique:Array[Dictionary]=[]
   for source_key in bone.keys:
    if not unique.is_empty() and float(unique[-1].time)==float(source_key.time):unique[-1]=source_key
    else:unique.append(source_key)
   if native.track_get_key_count(rotation)!=unique.size():mismatches+=1;continue
   for i in range(unique.size()):
    var key:Dictionary=unique[i]
    var q:Array=key.rotation
    var expected:=Quaternion(q[0],q[1],q[2],q[3])
    var actual:Quaternion=native.track_get_key_value(rotation,i)
    var error:=absf(1.0-absf(expected.dot(actual)))
    max_error=maxf(max_error,error)
    if error>0.000002 or absf(native.track_get_key_time(rotation,i)-float(key.time))>0.00001:mismatches+=1
    keys+=1
    if key.has("position"):
     if position<0:missing_tracks+=1;continue
     var v:Array=key.position
     var actual_v:Vector3=native.track_get_key_value(position,i)
     error=actual_v.distance_to(Vector3(v[0],v[1],v[2]));max_error=maxf(max_error,error)
     if error>0.00001:mismatches+=1
     keys+=1
    if key.has("scale"):
     if scale<0:missing_tracks+=1;continue
     var v:Array=key.scale
     var actual_v:Vector3=native.track_get_key_value(scale,i)
     if actual_v.distance_to(Vector3(v[0],v[1],v[2]))>0.00001:mismatches+=1
     keys+=1
 check("every native key matches source with explicit last-key-wins duplicate times",mismatches==0 and missing_tracks==0,{"keys":keys,"channels":channels,"mismatches":mismatches,"missing_tracks":missing_tracks,"max_error":max_error})
 var aliases_ok:=true
 for alias in source.aliases:
  if library.get_animation(alias)!=library.get_animation(source.aliases[alias]):aliases_ok=false
 check("active aliases preserve exact native animation objects",aliases_ok)
 check("VCS controls main locomotion and Colt actions",source.aliases.WALK_player.begins_with("vcs__ped__") and source.aliases.colt45_fire.begins_with("vcs__colt45__"))
 var bike_sources_ok:=true
 for block in catalog.blocks:
  if block.active and block.namespace in ["vcs__bikes","vcs__biked","vcs__bikev","vcs__bikeh"] and not "LCS Bike Animations PS2 Converted" in block.path:bike_sources_ok=false
 check("all four active bike blocks come from the LCS PS2 conversion",bike_sources_ok)
 var selection:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/stories_model_selection.json"))
 check("selective model extraction never unpacks full IMG",not selection.full_archive_unpacked and selection.models.size()==28)
 var models_ok:=true
 for row in selection.models:
  if not ResourceLoader.exists("res://assets/converted/models/"+row.role+".scn"):models_ok=false
 check("all 28 additional model roles have native scenes",models_ok)
 var db:ImportedGameplayDatabase=load("res://assets/converted/gameplay_database.tres")
 var moves_ok:=true
 for move in db.fight_moves:
  if move.animation_source not in ["null","default"] and (move.get("animation_clip","").is_empty() or not library.has_animation(move.animation_clip)):moves_ok=false
 check("VCS fist DAT moves bind to supplied clips",moves_ok)
 var report:={"assertions":results.size(),"failures":failures,"engine":Engine.get_version_info().string,"results":results,"source_keys":keys,"source_channels":channels,"reference_runtime_parity":false}
 FileAccess.open("res://tests/stories_assets_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("RESULT stories assets ",results.size()," / failures ",failures)
 quit(1 if failures else 0)
