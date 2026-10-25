class_name VehicleRecovery
extends RefCounted
## Recycle the same fixture only after the wreck delay and a clear spawn volume.
var profile:VehicleRespawnProfile=preload("res://tuning/vehicle_respawn.tres")
var car:DriveVehicle
var destroyed_age:=0.0
var retry_left:=0.0
var respawns:=0
func tick(dt:float) -> void:
 if car.damage.state!="destroyed":destroyed_age=0;retry_left=0;return
 destroyed_age+=dt;retry_left=maxf(0,retry_left-dt)
 if not profile.enabled or destroyed_age<profile.destroyed_seconds or retry_left>0:return
 retry_left=profile.retry_seconds
 for table in [car.seating.occupants,car.seating.reservations]:
  for index in table.keys():
   if not is_instance_valid(table[index]):table.erase(index)
 # Transition owners release living/dead occupants; recycling cannot steal a seat.
 if not car.seating.occupants.is_empty() or not car.seating.reservations.is_empty():return
 var point:=clear_spawn()
 if not point.is_finite():return
 car.damage.repair();car.reset_at(point)
 destroyed_age=0;retry_left=0;respawns+=1
func clear_spawn() -> Vector3:
 var space:=car.get_world_3d().direct_space_state
 var query:=PhysicsShapeQueryParameters3D.new()
 query.collision_mask=31;query.margin=0.08
 var excluded:Array[RID]=[car.get_rid()]
 for door in car.doors:excluded.append(door.get_rid())
 for fragment in car.parts.debris.values():
  if is_instance_valid(fragment):excluded.append(fragment.get_rid())
 query.exclude=excluded
 for ring in range(profile.clearance_rings+1):
  for sector in range(1 if ring==0 else 8):
   var angle:=TAU*sector/8.0
   var point:=car.spawn_position+Vector3(cos(angle),0,sin(angle))*ring*profile.clearance_spacing
   var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*3,1,excluded)
   var floor_hit:=space.intersect_ray(ray)
   if floor_hit.is_empty() or floor_hit.normal.y<0.8:continue
   if absf(floor_hit.position.y-car.spawn_floor_height)>0.7:continue
   point.y=floor_hit.position.y+car.spawn_position.y-(car.spawn_floor_height)
   var clear:=true
   for name in ["Hull","Cab"]:
    if car.kind=="bike" and name=="Cab":continue
    var shape:CollisionShape3D=car.get_node(name)
    query.shape=shape.shape;query.transform=Transform3D(Basis.IDENTITY,point)*shape.transform
    if not space.intersect_shape(query,1).is_empty():clear=false;break
   if clear:return point
 return Vector3.INF
