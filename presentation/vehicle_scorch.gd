class_name VehicleScorch
extends RefCounted
## Instance material overrides preserve shared textures and every other vehicle.
var car:DriveVehicle
var records:Array[Dictionary]=[]
func material(source:Material) -> Material:
 var result:BaseMaterial3D=source.duplicate() as BaseMaterial3D if source is BaseMaterial3D else StandardMaterial3D.new()
 result.albedo_color*=car.recovery.profile.scorched_tint
 result.roughness=maxf(result.roughness,0.92);result.metallic=minf(result.metallic,0.15)
 result.emission_enabled=false
 return result
func apply() -> void:
 if not records.is_empty():return
 var meshes:=car.find_children("*","MeshInstance3D",true,false)
 for fragment in car.parts.debris.values():
  if is_instance_valid(fragment):meshes.append_array(fragment.find_children("*","MeshInstance3D",true,false))
 for item in meshes:
  var mesh:=item as MeshInstance3D
  if mesh.mesh==null:continue
  var surfaces:Array[Material]=[]
  for i in range(mesh.mesh.get_surface_count()):surfaces.append(mesh.get_surface_override_material(i))
  records.append({"mesh":mesh,"override":mesh.material_override,"surfaces":surfaces})
  if mesh.material_override!=null:mesh.material_override=material(mesh.material_override)
  else:
   for i in range(mesh.mesh.get_surface_count()):mesh.set_surface_override_material(i,material(mesh.get_active_material(i)))
func restore() -> void:
 for record in records:
  if not is_instance_valid(record.mesh):continue
  record.mesh.material_override=record.override
  for i in range(record.surfaces.size()):record.mesh.set_surface_override_material(i,record.surfaces[i])
 records.clear()
