class_name HandlingDataMapper
extends RefCounted
## Explicit dimensions/units only; tire and suspension parity still needs runtime traces.
static func apply(car: DriveVehicle, record: Dictionary) -> void:
 if record.is_empty(): return
 car.profile = car.profile.duplicate()
 var cfg := car.profile
 cfg.mass = float(record.mass)
 cfg.max_speed = float(record.max_speed_kmh)/3.6
 cfg.steering_angle = deg_to_rad(float(record.steering_degrees))
 cfg.driven_front = record.drive in ["F","4"]
 cfg.driven_rear = record.drive in ["R","4"]
 # HandlingMgr parses acceleration * 0.4, then normalizes by 50².
 # Net driven-wheel forces are expressed here in N rather than per-wheel legacy dv.
 cfg.engine_force = cfg.mass*float(record.acceleration_source)*0.4
 cfg.brake_force = cfg.mass*float(record.brake_deceleration_source)
 var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
 cfg.spring_rate = cfg.mass*gravity/(4.0*cfg.static_sag)
 cfg.damper = 2.0*sqrt(cfg.spring_rate*cfg.mass/4.0)*cfg.damping_ratio
 cfg.brake_bias = float(record.brake_bias)
 var center: Array = record.center_of_mass_source
 cfg.center_of_mass = Vector3(center[0],center[2],-center[1])
 cfg.launch_force_multiplier=1.6
 cfg.maximum_lateral_acceleration=7.5
 cfg.center_of_mass.y-=0.45
 car.mass = cfg.mass
 car.center_of_mass = cfg.center_of_mass
