class_name BikeEjectionSolver
extends RefCounted
## Crash release needs a torso volume, not a standing capsule beside a wall.
static func destination(actor:CharacterMotor,car:DriveVehicle) -> Vector3:
 var normal_exit:=VehicleExitSolver.select(actor,car)
 if not normal_exit.is_empty():return normal_exit.position
 var space:=actor.get_world_3d().direct_space_state
 var shape:Shape3D=actor.reaction_body.get_child(0).shape
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=31;query.exclude=[actor.get_rid(),actor.reaction_body.get_rid()]
 var basis:=car.upright_basis()*Basis(Vector3.RIGHT,PI/2)
 for lift in [0.6,1.0,1.5]:
  for offset in [Vector3.ZERO,Vector3(0,0,0.8),Vector3(-0.8,0,0),Vector3(0.8,0,0)]:
   var point:Vector3=car.seat_position()+Vector3.UP*lift+car.upright_basis()*offset
   query.transform=Transform3D(basis,point)
   if not space.intersect_shape(query,1).is_empty():continue
   var ray:=PhysicsRayQueryParameters3D.create(car.seat_position(),point,1,[actor.get_rid(),car.get_rid()])
   if space.intersect_ray(ray).is_empty():return point
 return Vector3.INF
