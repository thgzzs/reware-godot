class_name AnimationRigBinding
extends RefCounted
static func canonical(name:String) -> String:
 return name.strip_edges().to_lower().replace("fingers","finger")
static func indices_for(animation:Animation,target:String,bone_id:=-1) -> Array:
 var metadata:Array=animation.get_meta("ifp_tracks",[])
 if metadata.is_empty():
  var path:=NodePath("Skeleton3D:"+target)
  return [animation.find_track(path,Animation.TYPE_ROTATION_3D),animation.find_track(path,Animation.TYPE_POSITION_3D),animation.find_track(path,Animation.TYPE_SCALE_3D)]
 var fallback:Array=[-1,-1,-1]
 var cursor:=0
 for track in metadata:
  if track.kind=="K000":continue
  var indices:Array=[cursor,-1,-1];cursor+=1
  if track.kind in ["KRT0","KRTS"]:indices[1]=cursor;cursor+=1
  if track.kind=="KRTS":indices[2]=cursor;cursor+=1
  var source_id:int=int(track.bone_id) if track.get("bone_id")!=null else int(track.sibling_metadata[0]) if track.get("sibling_metadata")!=null else -1
  if bone_id>=0 and source_id==bone_id:return indices
  if canonical(track.bone)==canonical(target):fallback=indices
 return fallback
static func build(animation:Animation,skeleton:Skeleton3D,profile:AnimationRigProfile) -> Array:
 var rows:=[]
 for i in range(skeleton.get_bone_count()):
  var name:=skeleton.get_bone_name(i)
  var id:int=profile.bone_ids.get(name,-1) if profile!=null else -1
  rows.append(indices_for(animation,name,id))
 return rows
