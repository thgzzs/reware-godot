class_name PedestrianImpactProbe
extends ShapeCast3D
## Predict the chassis sweep before its next solve; reactions own ped motion.
var car: DriveVehicle
var impacts := 0
func configure(vehicle: DriveVehicle) -> void:
	car = vehicle
	shape = car.get_node("Hull").shape
	collision_mask = 10
	max_results = 16
	enabled = false
	exclude_parent = true
	car.add_child(self)
func sweep(dt: float) -> void:
	if car.linear_velocity.length()<1.0: return
	target_position = car.global_basis.inverse()*car.linear_velocity*dt
	force_shapecast_update()
	for i in range(get_collision_count()):
		var ped := get_collider(i) as CharacterMotor
		if ped==null or not ped.control_enabled or ped.health.health<=0: continue
		var relative := car.linear_velocity-ped.velocity
		var direction := ped.global_position-car.global_position
		direction.y = 0
		if direction.length_squared()<0.001: direction = relative
		var closing := maxf(0,relative.dot(direction.normalized()))
		if closing<ped.actions.profile.impact_min_speed: continue
		ped.receive_vehicle_impact(car,closing,direction)
		impacts += 1
