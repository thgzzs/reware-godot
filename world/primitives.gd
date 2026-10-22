class_name LabGeometry
extends RefCounted
static func material(color: Color, roughness: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
 var result := StandardMaterial3D.new()
 result.albedo_color = color
 result.roughness = roughness
 result.metallic = metal
 return result
static func box(parent: Node, size: Vector3, at: Vector3, color: Color, solid := false) -> Node3D:
 var mesh := BoxMesh.new()
 mesh.size = size
 var model := MeshInstance3D.new()
 model.mesh = mesh
 model.material_override = material(color)
 if solid:
  var body := StaticBody3D.new()
  body.position = at
  parent.add_child(body)
  var shape := CollisionShape3D.new()
  var box_shape := BoxShape3D.new()
  box_shape.size = size
  shape.shape = box_shape
  body.add_child(shape)
  body.add_child(model)
  return body
 model.position = at
 parent.add_child(model)
 return model
static func label(parent: Node, value: String, at: Vector3, size := 48) -> Label3D:
 var node := Label3D.new()
 node.text = value
 node.position = at
 node.font_size = size
 node.pixel_size = 0.01
 node.modulate = Color("d8f4ee")
 node.outline_size = 4
 parent.add_child(node)
 return node
