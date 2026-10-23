extends SceneTree
var count:=0
var failures:=0
func _initialize() -> void:
 scan("res://")
 print("SCRIPT CHECK ",count," parsed / ",failures," failures")
 quit(1 if failures else 0)
func scan(folder:String) -> void:
 for name in DirAccess.get_directories_at(folder):
  if not name.begins_with("."):scan(folder.path_join(name))
 for name in DirAccess.get_files_at(folder):
  var path:=folder.path_join(name)
  if name.ends_with(".gd") and path!="res://tools/check_project_scripts.gd":
   count+=1
   if load(path)==null:failures+=1
