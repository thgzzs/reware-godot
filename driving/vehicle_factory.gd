class_name VehicleFactory
extends RefCounted
## Spawn independent physics fixtures while native replacement meshes are unavailable.
static func spawn(parent: Node3D, variant: VehicleVariant, db: ImportedGameplayDatabase, at: Vector3, library:AnimationLibrary=null) -> DriveVehicle:
 var car: DriveVehicle = load("res://scenes/vehicle.tscn").instantiate()
 car.name = variant.id
 car.position = at
 car.profile = load("res://tuning/handling.tres").duplicate()
 parent.add_child(car)
 car.variant=variant
 car.kind=variant.kind
 car.bike_animation=variant.bike_animation
 var record := db.find_record("handling",variant.handling_id)
 HandlingDataMapper.apply(car,record)
 if record.is_empty():record=db.find_record("handling","BIKE")
 var dimensions: Array = record.dimensions_source
 var size := Vector3(float(dimensions[0]),0.50,float(dimensions[1]))
 var hull := car.get_node("Hull") as CollisionShape3D
 hull.shape = hull.shape.duplicate()
 (hull.shape as BoxShape3D).size = size
 var body := car.get_node("Body") as MeshInstance3D
 body.mesh = body.mesh.duplicate()
 (body.mesh as BoxMesh).size = size
 var paint := StandardMaterial3D.new();paint.albedo_color=variant.display_color
 body.material_override = paint
 for i in range(4):
  car.mounts[i].x = (-1 if i%2==0 else 1)*size.x*0.43
  car.mounts[i].z = (-1 if i<2 else 1)*size.z*0.32
 car.seating.configure(Vector3(-size.x*0.2,0.08,-size.z*0.05),Vector3(size.x*0.2,0.08,size.z*0.20) if variant.seat_count>2 else Vector3.INF)
 car.impact_probe.shape = hull.shape
 if variant.door_count==4:
  for side in range(2):
   var door := VehicleDoor.new()
   door.configure(car,side+2)
   car.doors.append(door)
  for seat in car.seating.definitions:
   if seat.id.begins_with("rear_"):seat.door+=2
 var assets:=load("res://tuning/placeholder_assets.tres").duplicate() as PlaceholderAssets
 assets.vehicle_scene=variant.model_scene
 assets.vehicle_hull_size=size
 if variant.kind=="bike":
  car.bike=BikeDynamics.new()
  car.bike.configure(car)
  if ResourceLoader.exists(variant.model_scene):ModelPlaceholderSetup.apply_bike(car,assets)
 else:
  if ResourceLoader.exists(variant.model_scene):ModelPlaceholderSetup.apply_vehicle(car,assets)
 VehicleHitboxes.refresh(car,car.damage.windshield_ok)
 car.parts.bind_model()
 VehicleEntryGeometry.configure(car,library)
 if car.kind=="bike":car.rotation.z=0
 var label := LabGeometry.label(car,variant.id+" / "+variant.handling_id,Vector3(0,1.9,0),18)
 label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 car.set_meta("diagnostic_vehicle",variant.diagnostic_only)
 return car
