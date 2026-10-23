class_name VehicleFactory
extends RefCounted
## Spawn independent physics fixtures while native replacement meshes are unavailable.
static func spawn(parent: Node3D, variant: VehicleVariant, db: ImportedGameplayDatabase, at: Vector3) -> DriveVehicle:
 var car: DriveVehicle = load("res://scenes/vehicle.tscn").instantiate()
 car.name = variant.id
 car.position = at
 car.profile = load("res://tuning/handling.tres").duplicate()
 parent.add_child(car)
 var record := db.find_record("handling",variant.handling_id)
 HandlingDataMapper.apply(car,record)
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
 VehicleHitboxes.refresh(car)
 var label := LabGeometry.label(car,variant.handling_id+" physics fixture / mesh pending",Vector3(0,1.9,0),18)
 label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 car.set_meta("diagnostic_vehicle",true)
 return car
