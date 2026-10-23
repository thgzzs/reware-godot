class_name VehicleDamage
extends Node
signal state_changed(next: String)
signal exploded
var profile: VehicleDamageProfile = preload("res://tuning/vehicle_damage.tres")
var car: DriveVehicle
var health := 1000.0
var state := "healthy"
var fire_age := 0.0
var wheel_flat := [false,false,false,false]
var glass_health := 35.0
var glass_state := "intact"
var contacts := {}
var pending_collision_damage := 0.0
var pending_contacts: Array[DamageEvent] = []
var previous_velocity := Vector3.ZERO
var previous_angular := Vector3.ZERO
var collision_clock := 0.0
var damage_times := {}
var damaged_panels := false
var explosion_count := 0
var windshield_ok: Node3D
var windshield_damaged: Node3D
var glass_region: Area3D
func configure(owner_car: DriveVehicle) -> void:
 car = owner_car
 health = profile.maximum_health
 glass_health = profile.windshield_health
func receive_hit(event: DamageEvent) -> void:
 if state=="destroyed": return
 car.parts.receive(event)
 var engine_scale := car.parts.profile.engine_melee_scale if event.kind=="melee" else 1.0
 health = maxf(0,health-event.amount*engine_scale)
 if health<=0: detonate()
 elif health<profile.fire_health: change("burning")
 elif health<profile.smoke_health: change("smoking")
 else: change("damaged")
func burst_tire(index: int) -> void:
 if index<0 or index>=4 or wheel_flat[index] or state=="destroyed": return
 wheel_flat[index] = true
func hit_glass(event: DamageEvent) -> void:
 if glass_state=="shattered": return
 glass_health = maxf(0,glass_health-event.amount)
 glass_state = "shattered" if glass_health<=0 else "cracked"
 update_glass()
func update_glass() -> void:
 if is_instance_valid(windshield_ok): windshield_ok.visible = glass_state=="intact"
 if is_instance_valid(windshield_damaged): windshield_damaged.visible = glass_state=="cracked"
 if is_instance_valid(glass_region): glass_region.set_deferred("collision_layer",0 if glass_state=="shattered" else 32)
func sample_contacts(direct: PhysicsDirectBodyState3D) -> void:
 if state=="destroyed": return
 collision_clock += direct.step
 var active := {}
 var damaged_this_step := {}
 for i in range(direct.get_contact_count()):
  var other := direct.get_contact_collider_object(i)
  if other is CharacterMotor or other is PedReactionBody: continue
  if other is VehiclePartDebris and other.source_car==car:continue
  var id := direct.get_contact_collider_id(i)
  active[id] = true
  var normal := direct.get_contact_local_normal(i) # Jolt reports world-space normals despite the API name.
  var lever := direct.get_contact_local_position(i)-direct.transform.origin-direct.center_of_mass
  var own_velocity := previous_velocity+previous_angular.cross(lever)
  var closing := maxf(0,-(own_velocity-direct.get_contact_collider_velocity_at_position(i)).dot(normal))
  if closing>profile.collision_min_speed and not contacts.has(id) and not damaged_this_step.has(id) and collision_clock-float(damage_times.get(id,-100))>=profile.collision_rearm_seconds:
   damaged_this_step[id] = true
   damage_times[id] = collision_clock
   var other_mass: float = other.mass if other is RigidBody3D else INF
   var reduced := car.mass if is_inf(other_mass) else car.mass*other_mass/(car.mass+other_mass)
   var amount:=0.5*reduced*pow(closing-profile.collision_min_speed,2)*profile.collision_health_per_joule
   pending_collision_damage+=amount
   var event:=DamageEvent.make(amount,direct.get_contact_local_position(i),-normal,"collision",other)
   event.normal=normal
   pending_contacts.append(event)
 contacts = active
 previous_velocity = direct.linear_velocity
 previous_angular = direct.angular_velocity
 for id in damage_times.keys():
  if collision_clock-float(damage_times[id])>2.0 and not active.has(id): damage_times.erase(id)
func tick(dt: float) -> void:
 for event in pending_contacts: car.parts.receive(event)
 pending_contacts.clear()
 if pending_collision_damage>0:
  var value := pending_collision_damage
  pending_collision_damage = 0
  health=maxf(0,health-value)
  if health<=0:detonate()
  elif health<profile.fire_health:change("burning")
  elif health<profile.smoke_health:change("smoking")
  else:change("damaged")
 if state=="burning":
  fire_age += dt
  if fire_age>=profile.burn_seconds: detonate()
func change(next: String) -> void:
 if state==next: return
 state = next
 state_changed.emit(state)

func detonate() -> void:
 if state=="destroyed": return
 health = 0
 change("destroyed")
 car.park()
 explosion_count += 1
 for occupant in car.seating.occupants.values():
  if is_instance_valid(occupant): DamageEvent.deliver(occupant,DamageEvent.make(1000,occupant.global_position,Vector3.UP,"explosion",car))
 GameplayExplosion.emit(car,car.global_position,profile.blast_radius,profile.blast_damage,profile.blast_impulse,car)
 exploded.emit()
func repair() -> void:
 health = profile.maximum_health
 fire_age = 0
 contacts.clear()
 pending_contacts.clear()
 car.parts.repair()
 pending_collision_damage = 0
 previous_velocity = Vector3.ZERO
 previous_angular = Vector3.ZERO
 damage_times.clear()
 explosion_count = 0
 wheel_flat = [false,false,false,false]
 glass_health = profile.windshield_health
 glass_state = "intact"
 damaged_panels = false
 state = "healthy"
 for node in car.find_children("*","Node3D",true,false):
  if String(node.name).ends_with("_hi_dam"): node.hide()
  elif String(node.name).ends_with("_hi_ok"): node.show()
 update_glass()
 state_changed.emit(state)
