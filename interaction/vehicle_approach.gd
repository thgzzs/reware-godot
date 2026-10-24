class_name VehicleApproach
extends RefCounted
## Plan once around a convex lab chassis; walk with the production collision motor.
var points: Array[Vector3] = []
var index := 0
var elapsed := 0.0
var stalled := 0.0
var best_distance := INF
var goal := Vector3.ZERO
var actor: CharacterMotor
var car: DriveVehicle
var profile: InteractionProfile
var shape_query:=PhysicsShapeQueryParameters3D.new()
func clear_segment(a: Vector3,b: Vector3) -> bool:
 shape_query.transform=Transform3D(Basis.IDENTITY,a+Vector3.UP*0.025)
 shape_query.motion=b-a
 return actor.get_world_3d().direct_space_state.cast_motion(shape_query)[0]>0.99
func floor_point(at: Vector3) -> Vector3:
 var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*1.5,at-Vector3.UP*profile.floor_max_drop,1,[actor.get_rid(),car.get_rid()])
 var hit:=actor.get_world_3d().direct_space_state.intersect_ray(ray)
 return hit.position+Vector3.UP*0.93 if not hit.is_empty() and hit.normal.y>=actor.slope_cos() else Vector3.INF
func plan(owner_actor: CharacterMotor, candidate: DriveVehicle, target: Vector3, tuning: InteractionProfile) -> bool:
 actor=owner_actor;car=candidate;goal=target;profile=tuning
 elapsed=0;stalled=0;best_distance=INF;index=0;points.clear()
 shape_query.shape=actor.normal_shape;shape_query.margin=0.001;shape_query.collision_mask=15
 shape_query.exclude=[actor.get_rid(),actor.reaction_body.get_rid()]
 if clear_segment(actor.global_position,goal):points.append(goal);return actor.global_position.distance_to(goal)<=profile.maximum_approach_path
 var hull:Vector3=(car.get_node("Hull").shape as BoxShape3D).size*0.5
 var x:=hull.x+profile.approach_clearance
 var z:=hull.z+profile.approach_clearance
 var corners:Array[Vector3]=[]
 for offset in [Vector3(-x,0,-z),Vector3(x,0,-z),Vector3(x,0,z),Vector3(-x,0,z)]:corners.append(floor_point(car.global_transform*offset))
 var best:=INF
 for first in range(4):
  for direction in [-1,1]:
   var route:Array[Vector3]=[]
   var prior:=actor.global_position
   var length:=0.0
   for steps in range(4):
    var point:=corners[posmod(first+steps*direction,4)]
    if not point.is_finite() or not clear_segment(prior,point):break
    length+=prior.distance_to(point);route.append(point);prior=point
    if clear_segment(point,goal) and length+point.distance_to(goal)<minf(best,profile.maximum_approach_path):
     best=length+point.distance_to(goal);points=route.duplicate();points.append(goal)
 return not points.is_empty()
func command() -> GameplayCommand:
 var cmd:=GameplayCommand.new()
 var delta:=points[index]-actor.global_position;delta.y=0
 cmd.walk=delta.length()<profile.approach_run_distance
 if delta.length()>profile.approach_arrival_radius:
  cmd.move=Vector2(delta.x,delta.z).normalized()
  cmd.locomotion_scale=clampf(delta.length()/profile.approach_slow_radius,0.08,1)
  # Native start clips contain planted anticipation; slowing that clock can
  # exhaust the stall timeout before the first physical step near a door.
  if actor.reference_enabled and actor.reference_motion.phase in ["idle","start"]:
   cmd.locomotion_scale=maxf(cmd.locomotion_scale,profile.approach_start_scale)
 return cmd
func advance(dt: float, target: Vector3) -> bool:
 elapsed+=dt;goal=target;points[-1]=target
 var delta:=points[index]-actor.global_position;delta.y=0
 if delta.length()<=profile.approach_arrival_radius:
  if index<points.size()-1:index+=1;best_distance=INF;stalled=0
  return index==points.size()-1 and Vector2(goal.x-actor.global_position.x,goal.z-actor.global_position.z).length()<=profile.approach_arrival_radius
 if delta.length()<best_distance-0.015:best_distance=delta.length();stalled=0
 else:stalled+=dt
 return false
