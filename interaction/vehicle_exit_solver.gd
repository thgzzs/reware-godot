class_name VehicleExitSolver
extends RefCounted
## Upright world-space capsule clearance for tilted vehicles and moving bailouts.
static func select(actor:CharacterMotor, car:DriveVehicle, required:=-1, seat_index:=0, prefer_rear:=false) -> Dictionary:
 var space:=actor.get_world_3d().direct_space_state
 var forward:=Vector3(-car.global_basis.z.x,0,-car.global_basis.z.z).normalized()
 if forward.length_squared()<0.1:forward=Vector3.FORWARD
 var right:=forward.cross(Vector3.UP).normalized()
 var hull:Vector3=(car.get_node("Hull").shape as BoxShape3D).size
 var width:=maxf(1.2,hull.x*0.5+0.55)
 var length:=maxf(1.6,hull.z*0.5+0.55)
 var offsets:Array[Vector3]=[-right*width,right*width,-forward*length,forward*length,-right*(width+0.65),right*(width+0.65),(-right-forward).normalized()*(length+0.4),(right-forward).normalized()*(length+0.4),(-right+forward).normalized()*(length+0.4),(right+forward).normalized()*(length+0.4)]
 var order:=[2,6,7] if prefer_rear else range(offsets.size())
 # Prefer the occupied side in world space when inverted; crossing the whole
 # cabin would pull the crawl pose through the underside of the vehicle.
 var occupied_side := (car.seat_position(seat_index)-car.global_position).dot(right)
 if not prefer_rear and (car.global_basis.x.dot(Vector3.UP)>0.2 or occupied_side>0.05):order[0]=1;order[1]=0
 for index in order:
  if required>=0 and index!=required:continue
  var point:=car.global_position+offsets[index]
  var ray:=PhysicsRayQueryParameters3D.create(Vector3(point.x,maxf(actor.global_position.y,car.global_position.y)+3,point.z),Vector3(point.x,car.global_position.y-5,point.z),1,[actor.get_rid(),car.get_rid()])
  var floor_hit:=space.intersect_ray(ray)
  if floor_hit.is_empty() or floor_hit.normal.y<actor.slope_cos():continue
  point=floor_hit.position+Vector3.UP*0.93
  var volume:=PhysicsShapeQueryParameters3D.new()
  volume.shape=actor.normal_shape
  volume.transform=Transform3D(Basis.IDENTITY,point)
  volume.collision_mask=31
  volume.exclude=[actor.get_rid(),actor.reaction_body.get_rid()]
  volume.margin=0.01
  if not space.intersect_shape(volume,1).is_empty():continue
  # A short torso sphere can crawl through a tilted opening without casting a
  # full standing capsule through the floor. World blockers still obstruct it.
  var torso:=SphereShape3D.new();torso.radius=0.24
  var route:=PhysicsShapeQueryParameters3D.new()
  route.shape=torso
  var start:=car.seat_position(seat_index)
  start.y=maxf(start.y,floor_hit.position.y+0.38)
  route.transform=Transform3D(Basis.IDENTITY,start)
  route.motion=point-start
  route.collision_mask=1|8
  route.exclude=[actor.get_rid(),actor.reaction_body.get_rid(),car.get_rid()]
  if space.cast_motion(route)[0]<0.99:continue
  return {"position":point,"side":0 if car.to_local(point).x<0 else 1,"index":index,"special":true}
 return {}
