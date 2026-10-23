class_name VehiclePartDebris
extends RigidBody3D
## Spawned once when a configured panel reaches its terminal state.
var age:=0.0
var source_car:DriveVehicle
var source_grace:=true
var lifetime:=25.0
func configure(car:DriveVehicle,source:Node3D,bounds:AABB,event:DamageEvent) -> void:
 source_car=car
 mass=14.0
 continuous_cd=true
 collision_layer=8;collision_mask=15
 linear_damp=0.1;angular_damp=0.3
 var shape:=CollisionShape3D.new()
 var box:=BoxShape3D.new();box.size=bounds.size.max(Vector3.ONE*0.04)
 shape.shape=box
 add_child(shape)
 var clone:=source.duplicate() as Node3D
 for child in clone.find_children("*","Area3D",true,false):child.free()
 clone.visible=true
 add_child(clone)
 car.get_parent().add_child(self)
 global_transform=Transform3D(car.global_basis,car.global_transform*bounds.get_center())
 clone.global_transform=source.global_transform
 clone.visible=true
 add_collision_exception_with(car)
 linear_velocity=car.linear_velocity+car.angular_velocity.cross(global_position-car.global_position)
 var outward:=(global_position-car.global_position).normalized()
 angular_velocity=car.angular_velocity+event.direction.cross(Vector3.UP)*clampf(event.amount*0.012,0.5,3.0)
 apply_impulse(outward*minf(30,event.amount*0.15)+Vector3.UP*mass*2.5,event.point-global_position)
func receive_hit(event:DamageEvent) -> void:
 sleeping=false
 apply_impulse(event.direction*minf(50,event.amount),event.point-global_position)
func _physics_process(dt:float) -> void:
 age+=dt
 if source_grace and age>0.1:
  if is_instance_valid(source_car):remove_collision_exception_with(source_car)
  source_grace=false
 if age>lifetime:queue_free()
