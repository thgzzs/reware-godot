class_name VehicleHitRegion
extends Area3D
var car: DriveVehicle
var kind := "body"
var wheel := -1
var part_id := ""
func configure(owner_car: DriveVehicle, type: String, shape: Shape3D, local_pose: Transform3D) -> void:
 car = owner_car
 kind = type
 collision_layer = 32
 collision_mask = 0
 monitoring = false
 monitorable = true
 var collider := CollisionShape3D.new()
 collider.shape = shape
 add_child(collider)
 transform = local_pose
func receive_hit(event: DamageEvent) -> void:
 if kind=="tire": car.damage.burst_tire(wheel)
 elif kind=="glass": car.damage.hit_glass(event)
 else:
  if not part_id.is_empty():event.part=part_id
  car.damage.receive_hit(event)
func receive_damage(amount: float, point: Vector3, direction: Vector3) -> void:
 receive_hit(DamageEvent.make(amount,point,direction))
