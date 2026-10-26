class_name PedRecoverySolver
extends RefCounted
## Native Jolt queries plan clearance; the live torso and bike retain collision.
var profile:PedRecoveryProfile=preload("res://tuning/ped_recovery.tres")
var body:PedReactionBody
var collider:CollisionShape3D
var floor_query:=PhysicsRayQueryParameters3D.new()
var stand_query:=PhysicsShapeQueryParameters3D.new()
var route_query:=PhysicsShapeQueryParameters3D.new()
var probe_left:=0.0
var destination:=Vector3.INF
var attempts:=0
var impulses:=0
var blocked:=false
func reset() -> void:
 probe_left=0;destination=Vector3.INF;blocked=false
func getup_obstructed() -> bool:
 # Revalidate vehicles throughout get-up, without treating the supporting
 # ground contact as an obstruction to the standing capsule.
 stand_query.shape=body.actor.normal_shape
 stand_query.transform=Transform3D(Basis.IDENTITY,body.actor.global_position)
 stand_query.collision_mask=4
 stand_query.exclude=[body.get_rid(),body.actor.get_rid()];stand_query.margin=0.003
 return not body.get_world_3d().direct_space_state.intersect_shape(stand_query,1).is_empty()
func floor_at(at:Vector3) -> Dictionary:
 floor_query.from=at+Vector3.UP*0.6;floor_query.to=at-Vector3.UP*1.3
 floor_query.collision_mask=5;floor_query.exclude=[body.get_rid(),body.actor.get_rid()]
 for i in range(8):
  var hit:=body.get_world_3d().direct_space_state.intersect_ray(floor_query)
  if hit.is_empty():return {}
  var bike:=hit.collider as DriveVehicle
  if bike!=null and bike.kind=="bike":
   var skip:=floor_query.exclude;skip.append(bike.get_rid());floor_query.exclude=skip
   continue
  return hit if hit.normal.y>=maxf(profile.minimum_floor_dot,body.actor.slope_cos()) else {}
 return {}
func standing(at:Vector3) -> Array[Dictionary]:
 stand_query.shape=body.actor.normal_shape;stand_query.transform=Transform3D(Basis.IDENTITY,at)
 stand_query.collision_mask=31;stand_query.exclude=[body.get_rid(),body.actor.get_rid()];stand_query.margin=0.003
 return body.get_world_3d().direct_space_state.intersect_shape(stand_query,32)
func clear_route(from:Vector3,to:Vector3,bike:DriveVehicle) -> bool:
 var distance:=Vector2(to.x-from.x,to.z-from.z).length()
 var steps:=maxi(1,int(ceil(distance/profile.path_step)))
 var capsule:=collider.shape as CapsuleShape3D
 var basis:=body.global_basis*collider.basis
 route_query.shape=capsule;route_query.collision_mask=31
 route_query.exclude=[body.get_rid(),body.actor.get_rid(),bike.get_rid()];route_query.margin=0.003
 for i in range(1,steps+1):
  var p:=from.lerp(to,float(i)/steps)
  var hit:=floor_at(p)
  if hit.is_empty() or absf(hit.position.y-(from.y-0.93))>profile.maximum_height_change:return false
  var extent:=capsule.radius+maxf(0,capsule.height*0.5-capsule.radius)*absf(basis.y.dot(hit.normal))
  p=hit.position+hit.normal*(extent+0.02)
  route_query.transform=Transform3D(basis,p)
  if not body.get_world_3d().direct_space_state.intersect_shape(route_query,1).is_empty():return false
 return true
func find_destination(origin:Vector3,bike:DriveVehicle) -> Vector3:
 var away:=origin-bike.global_position;away.y=0
 if away.length_squared()<0.01:away=bike.upright_basis().x
 away=away.normalized()
 for radius in profile.search_radii:
  for i in range(profile.directions):
   var sector:=0 if i==0 else int((i+1)/2)*(1 if i%2==1 else -1)
   var dir:=away.rotated(Vector3.UP,TAU*sector/profile.directions)
   var p:=origin+dir*radius
   var hit:=floor_at(p)
   if hit.is_empty():continue
   p.y=hit.position.y+0.93
   if standing(p).is_empty() and clear_route(origin,p,bike):return p
 return Vector3.INF
func tick(dt:float) -> void:
 probe_left=maxf(0,probe_left-dt)
 if body.actor.health.health<=0 or body.actor.actions.life!="down" or not body.supported or body.age<maxf(body.minimum_recovery_age,body.profile.recovery_delay):return
 if body.linear_velocity.length()>body.profile.recovery_speed:return
 var floor_hit:=floor_at(body.global_position)
 if floor_hit.is_empty():return
 var origin:Vector3=floor_hit.position+Vector3.UP*0.93
 var blockers:=standing(origin)
 blocked=not blockers.is_empty()
 if not blocked:destination=Vector3.INF;return
 var bike:DriveVehicle
 for hit in blockers:
  var candidate:=hit.collider as DriveVehicle
  if candidate!=null and candidate.kind=="bike" and candidate.linear_velocity.length()<profile.maximum_bike_speed:
   bike=candidate;break
 if bike==null:return
 if probe_left<=0:
  probe_left=profile.probe_interval;attempts+=1;destination=find_destination(origin,bike)
 if not destination.is_finite():return
 var dir:=destination-body.global_position;dir.y=0
 if dir.length()<0.1:destination=Vector3.INF;return
 dir=dir.normalized()
 var next:=origin+dir*minf(0.2,body.linear_velocity.length()*dt+0.08)
 if not clear_route(origin,next,bike):destination=Vector3.INF;return
 var planar:=Vector3(body.linear_velocity.x,0,body.linear_velocity.z)
 var change:=(dir*profile.separation_speed-planar).limit_length(profile.separation_acceleration*dt)
 var impulse:=change*body.mass
 body.sleeping=false;bike.sleeping=false
 body.apply_central_impulse(impulse)
 if not bike.freeze:bike.apply_central_impulse(-impulse)
 impulses+=1
