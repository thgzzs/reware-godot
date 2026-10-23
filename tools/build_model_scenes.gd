extends SceneTree
## Build native scenes from portable decoded data; no runtime RenderWare parser.
const OUTPUT := "res://assets/converted/models/"
var total_surfaces := 0
var total_triangles := 0
func _initialize() -> void: build.call_deferred()
func vec(a: Array) -> Vector3: return Vector3(a[0],a[1],a[2])
func transform(a: Array) -> Transform3D:
 return Transform3D(Basis(vec(a[0]),vec(a[1]),vec(a[2])),vec(a[3]))
func material(row: Dictionary) -> StandardMaterial3D:
 var m := StandardMaterial3D.new()
 var rgba: Array = row.color
 m.albedo_color = Color(rgba[0]/255.0,rgba[1]/255.0,rgba[2]/255.0,rgba[3]/255.0)
 # Legacy vehicle paint tags are replaced by a neutral editable placeholder paint.
 if rgba[0]==255 and rgba[1]==0 and rgba[2]==175:
  m.albedo_color = Color.WHITE
  m.set_meta("vehicle_color_channel",2)
 elif rgba[0]==60 and rgba[1]==255 and rgba[2]==0:
  m.albedo_color = Color.WHITE
  m.set_meta("vehicle_color_channel",1)
 m.roughness = 0.8
 if rgba[3]<255: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 if not row.textures.is_empty():
  var filename := String(row.textures[0]).to_lower().replace(" ","_")+".png"
  var path := OUTPUT+"textures/"+filename
  if ResourceLoader.exists(path): m.albedo_texture = load(path)
  else: push_error("Missing required material texture: "+path)
 m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 return m
func geometry(row: Dictionary) -> ArrayMesh:
 var mesh := ArrayMesh.new()
 var vertices := PackedVector3Array()
 var normals := PackedVector3Array()
 var uv := PackedVector2Array()
 for v in row.vertices: vertices.append(vec(v))
 for v in row.normals: normals.append(vec(v))
 for v in row.uv: uv.append(Vector2(v[0],v[1]))
 if normals.is_empty():
  normals.resize(vertices.size())
  for triangle in row.triangles:
   var n := (vertices[triangle[1]]-vertices[triangle[0]]).cross(vertices[triangle[2]]-vertices[triangle[0]])
   for i in range(3): normals[triangle[i]] += n
  for i in range(normals.size()): normals[i] = normals[i].normalized()
 var bones := PackedInt32Array()
 var weights := PackedFloat32Array()
 if row.has("skin"):
  for indices in row.skin.indices:
   for i in indices: bones.append(int(i))
  for values in row.skin.weights:
   for v in values: weights.append(float(v))
 for mat_index in range(row.materials.size()):
  var indices := PackedInt32Array()
  for t in row.triangles:
   if int(t[3])==mat_index:
    # Godot uses clockwise front faces, RenderWare's decoded triangles are CCW.
    indices.append(int(t[0])); indices.append(int(t[2])); indices.append(int(t[1]))
  if indices.is_empty(): continue
  var arrays := []
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX] = vertices
  arrays[Mesh.ARRAY_NORMAL] = normals
  if not uv.is_empty(): arrays[Mesh.ARRAY_TEX_UV] = uv
  if not bones.is_empty():
   arrays[Mesh.ARRAY_BONES] = bones
   arrays[Mesh.ARRAY_WEIGHTS] = weights
  arrays[Mesh.ARRAY_INDEX] = indices
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  mesh.surface_set_material(mesh.get_surface_count()-1,material(row.materials[mat_index]))
  total_surfaces += 1
  total_triangles += indices.size()/3
 return mesh
func own_children(node: Node, owner_node: Node) -> void:
 for child in node.get_children():
  child.owner = owner_node
  own_children(child,owner_node)
func build() -> void:
 var version := Engine.get_version_info()
 if version.major!=4 or version.minor!=7 or version.patch!=2 or version.status!="stable":
  push_error("Requires Godot 4.7.2 Stable")
  quit(1)
  return
 var source := "models.json"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--source="): source=arg.trim_prefix("--source=")
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+source))
 for model in data.models:
  var root_node := Node3D.new()
  root_node.name = String(model.role).capitalize()
  var frames: Array[Node3D] = []
  var skeleton: Skeleton3D
  if model.role=="player":
   skeleton = Skeleton3D.new()
   skeleton.name = "Skeleton3D"
   root_node.add_child(skeleton)
  for i in range(model.frames.size()):
   var f: Dictionary = model.frames[i]
   if skeleton!=null:
    var index := skeleton.add_bone(f.name)
    skeleton.set_bone_parent(index,int(f.parent))
    skeleton.set_bone_rest(index,transform(f.transform))
    skeleton.set_bone_pose_position(index,transform(f.transform).origin)
    skeleton.set_bone_pose_rotation(index,transform(f.transform).basis.get_rotation_quaternion())
   else:
    var node := Node3D.new()
    node.name = f.name
    (frames[int(f.parent)] if f.parent>=0 else root_node).add_child(node)
    node.transform = transform(f.transform)
    node.set_meta("source_frame",i)
    if String(f.name).ends_with("_dam") or String(f.name).ends_with("_vlo"): node.visible = false
    frames.append(node)
  var meshes: Array[ArrayMesh] = []
  for g in model.geometries: meshes.append(geometry(g))
  for atomic in model.atomics:
   var mesh := MeshInstance3D.new()
   mesh.name = "Geometry%d"%atomic.geometry
   mesh.mesh = meshes[int(atomic.geometry)]
   if skeleton!=null:
    root_node.add_child(mesh)
    mesh.skeleton = NodePath("../Skeleton3D")
    var source_skin: Dictionary = model.geometries[int(atomic.geometry)].skin
    var skin := Skin.new()
    for i in range(source_skin.frame_indices.size()):
     skin.add_bind(int(source_skin.frame_indices[i]),transform(source_skin.inverse_binds[i]))
    mesh.skin = skin
   else:
    frames[int(atomic.frame)].add_child(mesh)
  own_children(root_node,root_node)
  var packed := PackedScene.new()
  if packed.pack(root_node)!=OK or ResourceSaver.save(packed,OUTPUT+model.role+".scn",ResourceSaver.FLAG_COMPRESS)!=OK:
   push_error("Failed to pack model "+model.role)
   quit(1)
   return
  root_node.free()
 var report := {"models":data.models.size(),"surfaces":total_surfaces,"triangles_including_hidden_variants":total_triangles,"engine":version.string}
 var out := FileAccess.open(OUTPUT+("native_stories_model_report.json" if source!="models.json" else "native_model_report.json"),FileAccess.WRITE)
 out.store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report))
 quit()
