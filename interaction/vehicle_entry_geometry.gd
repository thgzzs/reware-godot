class_name VehicleEntryGeometry
extends RefCounted
## Calibrate side and travel from clip displacement, then respect the swept hull.
static func root_at(anim:Animation,at:float) -> Vector3:
 var track:int=AnimationRigBinding.indices_for(anim,"Root",0)[1]
 return anim.position_track_interpolate(track,clampf(at,0,anim.length)) if track>=0 else Vector3.ZERO
static func configure(car:DriveVehicle,library:AnimationLibrary) -> void:
 if library==null:return
 var names:={}
 for name in library.get_animation_list():names[String(name).to_lower()]=String(name)
 for side in range(2):
  var clip:="CAR_getin_"+("LHS"if side==0 else "RHS")
  if car.kind=="bike":
   for suffix in ["_jumponL","_jumponR"]:
    var candidate:String=names.get((car.bike_animation+suffix).to_lower(),"")
    if candidate.is_empty():continue
    var anim:=library.get_animation(candidate)
    var delta:=root_at(anim,anim.length)-root_at(anim,0)
    if delta.x*(1 if side==0 else -1)>0:clip=candidate;break
  if not names.has(clip.to_lower()):continue
  clip=names[clip.to_lower()]
  var anim:=library.get_animation(clip)
  car.entry_clips[side]=clip
  for seat_index in range(car.seating.definitions.size()):
   var seat:VehicleSeatDefinition=car.seating.definitions[seat_index]
   if car.kind!="bike" and seat.door%2!=side:continue
   var delta:=root_at(anim,anim.length)-root_at(anim,0)
   var start:=seat.anchor-delta
   var half:Vector3=(car.get_node("Hull").shape as BoxShape3D).size*0.5
   start.x=(-1 if side==0 else 1)*maxf(absf(start.x),half.x+0.38)
   var point:=Vector3(start.x,0.22,start.z)
   car.entry_points[Vector2i(seat_index,side)]=point
   if car.kind!="bike" or side==0:seat.approach=point
