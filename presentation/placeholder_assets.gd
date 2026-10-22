class_name PlaceholderAssets
extends Resource
## Semantic presentation bindings. Replace paths/transforms in one Resource.
@export_file("*.scn","*.tscn","*.glb") var character_scene := "res://assets/converted/models/player.scn"
@export_file("*.scn","*.tscn","*.glb") var vehicle_scene := "res://assets/converted/models/idaho.scn"
@export_file("*.scn","*.tscn","*.glb") var weapon_scene := "res://assets/converted/models/colt45.scn"
@export_file("*.scn","*.tscn","*.glb") var prop_scene := "res://assets/converted/models/trashcan.scn"
@export var character_offset := Vector3(0,0.115,0)
@export var weapon_offset := Vector3.ZERO
@export var weapon_rotation := Vector3.ZERO
@export var weapon_bone := "R Hand"
@export var vehicle_primary := Color("78544e")
@export var vehicle_secondary := Color("bdbba5")
@export var vehicle_hull_size := Vector3(2.1,0.6,5.5)
@export var vehicle_offset := Vector3(0,0.15,0)
@export var decorate_arena := false
@export_range(0,4,0.05) var directional_light_energy := 0.8
@export_range(0,2,0.05) var ambient_light_energy := 0.4
@export var weapon_scenes: Dictionary[String,String] = {}
@export var texture_paths: Dictionary[String,String] = {}
func scene(path: String) -> PackedScene:
 return load(path) as PackedScene if ResourceLoader.exists(path) else null
func texture(key: String) -> Texture2D:
 var path: String = texture_paths.get(key,"")
 return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null

