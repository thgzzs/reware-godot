class_name VehicleSeatMap
extends RefCounted
## Synchronous reservation/commit/transfer, with unique ownership per actor.
var definitions: Array[VehicleSeatDefinition] = []
var occupants := {}
var reservations := {}
func configure(front: Vector3, rear: Vector3 = Vector3.INF) -> void:
 definitions.clear()
 for row in [["driver",true,0,front],["front_passenger",false,1,Vector3(-front.x,front.y,front.z)]]:
  add(row[0],row[1],row[2],row[3])
 if rear.is_finite():
  add("rear_left",false,0,Vector3(-absf(rear.x),rear.y,rear.z))
  add("rear_right",false,1,Vector3(absf(rear.x),rear.y,rear.z))
func add(id: String, driver: bool, door: int, anchor: Vector3) -> void:
 var seat := VehicleSeatDefinition.new()
 seat.id = id; seat.driver = driver; seat.door = door; seat.anchor = anchor
 seat.approach = Vector3(-1.65 if door%2==0 else 1.65,0.22,0.05 if definitions.size()<2 else 0.65)
 seat.seated_clip = "CAR_sit" if driver else "CAR_sitp"
 definitions.append(seat)
func available(index: int) -> bool:
 return index>=0 and index<definitions.size() and not is_instance_valid(occupants.get(index)) and not is_instance_valid(reservations.get(index))
func reserve(actor: Node, index: int, transfer := false) -> bool:
 if not available(index): return false
 if not transfer:
  if occupants.values().has(actor) or reservations.values().has(actor): return false
 reservations[index] = actor
 return true
func commit(actor: Node, index: int) -> bool:
 if reservations.get(index)!=actor or is_instance_valid(occupants.get(index)): return false
 if occupants.values().has(actor): return false
 occupants[index] = actor
 reservations.erase(index)
 return true
func transfer(actor: Node, from: int, to: int) -> bool:
 if occupants.get(from)!=actor or reservations.get(to)!=actor or is_instance_valid(occupants.get(to)): return false
 occupants.erase(from)
 reservations.erase(to)
 occupants[to] = actor
 return true
func release(actor: Node) -> void:
 for slots in [occupants,reservations]:
  for index in slots.keys():
   if slots[index]==actor: slots.erase(index)
func choose(car: DriveVehicle, from: Vector3, passenger_only := false) -> int:
 var best := -1
 var distance := INF
 var side := 0 if car.to_local(from).x<0 else 1
 for i in range(definitions.size()):
  if not available(i) or (passenger_only and definitions[i].driver): continue
  var score := from.distance_squared_to(car.global_transform*definitions[i].approach)+(4.0 if definitions[i].door%2!=side else 0.0)
  if i>=2: score += 0.25
  if score<distance: distance=score;best=i
 return best
