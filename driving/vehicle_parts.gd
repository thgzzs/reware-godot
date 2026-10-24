class_name VehicleParts
extends RefCounted
## Per-instance panels, selected by semantic hit region or actual contact position.
var profile: VehiclePartProfile = preload("res://tuning/vehicle_parts.tres")
var car: DriveVehicle
var parts := {}
var events := 0
var debris := {}
func configure(owner_car: DriveVehicle) -> void:
 car=owner_car
 bind_model()
func bind_model() -> void:
 parts.clear()
 for node in car.find_children("*","Node3D",true,false):
  var name:=String(node.name)
  if not name.ends_with("_hi_ok") or "windscreen" in name:continue
  var id:=name.trim_suffix("_hi_ok")
  var damaged:=node.get_parent().get_node_or_null(name.replace("_hi_ok","_hi_dam")) as Node3D
  parts[id]={"health":profile.durability,"state":"intact","ok":node,"damaged":damaged,"anchor":car.to_local(node.global_position),"bounds":bounds_for(node)}
 if parts.is_empty():
  for row in [["bonnet",Vector3(0,0.1,-1.3)],["boot",Vector3(0,0.1,1.3)],["door_lf",Vector3(-0.8,0.4,0)],["door_rf",Vector3(0.8,0.4,0)],["roof",Vector3(0,0.8,0)]]:
   parts[row[0]]={"health":profile.durability,"state":"intact","ok":null,"damaged":null,"anchor":row[1],"bounds":AABB(row[1]-Vector3.ONE*0.3,Vector3.ONE*0.6)}
func bounds_for(node: Node3D) -> AABB:
 var result:=AABB()
 var started:=false
 for mesh in node.find_children("*","MeshInstance3D",true,false):
  var at: Transform3D=car.global_transform.affine_inverse()*mesh.global_transform
  var box: AABB=at*mesh.get_aabb()
  result=result.merge(box) if started else box
  started=true
 return result if started else AABB(car.to_local(node.global_position)-Vector3.ONE*0.2,Vector3.ONE*0.4)
func id_for_node(node: Node) -> String:
 var current:=node
 while current!=null and current!=car:
  var name:=String(current.name)
  if name.ends_with("_hi_ok") or name.ends_with("_hi_dam"):return name.trim_suffix("_hi_ok").trim_suffix("_hi_dam")
  current=current.get_parent()
 return ""
func nearest(point: Vector3) -> String:
 var local:=car.to_local(point)
 var best:=""
 var distance:=INF
 for id in parts:
  var box: AABB=parts[id].bounds
  var score:=local.distance_squared_to(local.clamp(box.position,box.end))+local.distance_squared_to(box.get_center())*0.025
  if score<distance:distance=score;best=id
 return best
func receive(event: DamageEvent) -> void:
 if parts.is_empty():bind_model()
 var id:=event.part if parts.has(event.part) else nearest(event.point)
 if id.is_empty():return
 var part: Dictionary=parts[id]
 var scale: float=profile.collision_scale if event.kind=="collision" else (profile.melee_scale if event.kind=="melee" else profile.bullet_scale)
 part.health=maxf(0,float(part.health)-event.amount*scale)
 part.state="destroyed" if part.health<=0 else ("damaged" if part.health<profile.durability*profile.damaged_fraction else "intact")
 if part.state=="destroyed" and profile.detachable.has(id) and not bool(part.get("detached",false)):
  var source:Node3D=part.damaged if is_instance_valid(part.damaged) else part.ok
  if is_instance_valid(source):
   var fragment:=VehiclePartDebris.new()
   fragment.configure(car,source,part.bounds,event)
   debris[id]=fragment
   part.detached=true
   if id.begins_with("door_"):
    for door in car.doors:
     if door.is_ancestor_of(source):door.collision_layer=0
 update_visual(part)
 events+=1
func receive_collision(event:DamageEvent) -> void:
 var primary:=nearest(event.point)
 receive(event)
 var local_normal:=car.global_basis.inverse()*event.normal
 var local_point:=car.to_local(event.point)
 var half:Vector3=(car.get_node("Hull").shape as BoxShape3D).size*0.5
 if event.amount>=profile.bonnet_collision_threshold and local_normal.z>0.55 and local_point.z< -half.z*0.35 and primary!="bonnet" and parts.has("bonnet"):
  var bonnet:=DamageEvent.make(event.amount*profile.bonnet_collision_share,event.point,event.direction,"collision",event.source)
  bonnet.part="bonnet";bonnet.normal=event.normal;receive(bonnet)
func update_visual(part: Dictionary) -> void:
 var damaged:Node3D=part.damaged
 var ok:Node3D=part.ok
 if is_instance_valid(ok):ok.visible=not part.get("detached",false) and (part.state=="intact" or not is_instance_valid(damaged))
 if is_instance_valid(damaged):damaged.visible=not part.get("detached",false) and part.state!="intact"
 for node in [ok,damaged]:
  if not is_instance_valid(node):continue
  for region in node.find_children("*","Area3D",true,false):
   if region is VehicleHitRegion:region.set_deferred("collision_layer",32 if node.visible else 0)
 if is_instance_valid(damaged) and damaged.visible:
  for mesh in damaged.find_children("*","MeshInstance3D",true,false):
   if mesh.get_child_count()>0:continue
   var region:=VehicleHitRegion.new()
   region.part_id=id_for_node(damaged)
   region.configure(car,"body",mesh.mesh.create_trimesh_shape(),Transform3D.IDENTITY)
   mesh.add_child(region)
func repair() -> void:
 for fragment in debris.values():
  if is_instance_valid(fragment):fragment.queue_free()
 debris.clear()
 for door in car.doors:door.collision_layer=16
 for part in parts.values():
  part.health=profile.durability;part.state="intact";part.detached=false;update_visual(part)
