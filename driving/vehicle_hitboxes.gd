class_name VehicleHitboxes
extends RefCounted
static func box(car: DriveVehicle, size: Vector3, position: Vector3, kind := "body") -> VehicleHitRegion:
 var shape := BoxShape3D.new()
 shape.size = size
 var region := VehicleHitRegion.new()
 region.configure(car,kind,shape,Transform3D(Basis.IDENTITY,position))
 car.add_child(region)
 return region
static func install(car: DriveVehicle) -> void:
 for i in car.wheel_indices():
  var shape := CylinderShape3D.new()
  shape.radius = car.profile.wheel_radius*1.05
  shape.height = 0.28
  var region := VehicleHitRegion.new()
  region.wheel = i
  region.name = "TireHit%d"%i
  region.configure(car,"tire",shape,Transform3D(Basis(Vector3.FORWARD,PI*0.5),Vector3.ZERO))
  car.wheel_visuals[i].add_child(region)
 # Solid ballistic panels leave the glass opening separate from the physics cab proxy.
 var size: Vector3 = (car.get_node("Hull").shape as BoxShape3D).size
 box(car,size,Vector3.ZERO)
 if car.kind=="bike":return
 box(car,Vector3(size.x*0.88,0.08,size.z*0.34),Vector3(0,0.84,0.15))
 var glass := box(car,Vector3(size.x*0.76,0.53,0.08),Vector3(0,0.52,-0.80),"glass")
 glass.name = "WindshieldHit"
 glass.rotation.x = -0.45
 car.damage.glass_region = glass

static func refresh(car: DriveVehicle, windshield: Node3D = null) -> void:
 for region in car.find_children("*","VehicleHitRegion",true,false): region.free()
 # Script class names are not native node types in find_children's type filter.
 for region in car.find_children("*","Area3D",true,false):
  if region is VehicleHitRegion: region.free()
 car.damage.glass_region=null
 install(car)
 if windshield==null and car.kind!="bike":return
 # Native triangles preserve wheel arches and door/window openings for bullet rays.
 for region in car.find_children("*","Area3D",true,false):
  if region is VehicleHitRegion and region.kind=="body": region.free()
 for mesh in car.find_children("*","MeshInstance3D",true,false):
  if not String(mesh.name).begins_with("Geometry") or not mesh.is_visible_in_tree(): continue
  if windshield!=null and windshield.is_ancestor_of(mesh): continue
  var region := VehicleHitRegion.new()
  region.configure(car,"body",mesh.mesh.create_trimesh_shape(),Transform3D.IDENTITY)
  region.part_id=car.parts.id_for_node(mesh)
  mesh.add_child(region)
 if windshield==null:return
 var points := PackedVector3Array()
 for mesh in windshield.find_children("*","MeshInstance3D",true,false):
  var local_pose: Transform3D = car.global_transform.affine_inverse()*mesh.global_transform
  for surface in range(mesh.mesh.get_surface_count()):
   var arrays: Array = mesh.mesh.surface_get_arrays(surface)
   var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
   for i in range(vertices.size()):
    var normal: Vector3 = (local_pose.basis*normals[i]).normalized() if normals.size()>i else Vector3.FORWARD
    points.append(local_pose*vertices[i]+normal*0.015)
    points.append(local_pose*vertices[i]-normal*0.015)
 if points.size()>=8:
  var shape := ConvexPolygonShape3D.new()
  shape.points = points
  var region := car.damage.glass_region as VehicleHitRegion
  region.transform = Transform3D.IDENTITY
  (region.get_child(0) as CollisionShape3D).shape = shape
