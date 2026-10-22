class_name ImportedAssetSetup
extends RefCounted
const LIBRARY_PATH := "res://assets/converted/ped_library.res"
const DATABASE_PATH := "res://assets/converted/gameplay_database.tres"
static func available() -> bool:
 return FileAccess.file_exists(LIBRARY_PATH) and FileAccess.file_exists(DATABASE_PATH)
static func apply(arena: Node3D) -> void:
 var lib: AnimationLibrary = load(LIBRARY_PATH)
 var db: ImportedGameplayDatabase = load(DATABASE_PATH)
 arena.reference_library = lib
 arena.reference_database = db
 arena.actor.configure_reference(db,"STAT_PLAYER",lib)
 var source_weapon := db.find_record("weapons","Colt45")
 arena.weapon.profile = arena.weapon.profile.duplicate()
 arena.weapon.profile.display_name = source_weapon.name
 arena.weapon.profile.interval = source_weapon.firing_rate_ms/1000.0
 arena.weapon.profile.reload_seconds = source_weapon.reload_ms/1000.0
 arena.weapon.profile.magazine_size = int(source_weapon.clip_size)
 arena.weapon.profile.damage = source_weapon.damage
 arena.weapon.profile.range_meters = source_weapon.range
 arena.weapon.magazine = int(source_weapon.clip_size)
 # Only dimensionally understood fields are applied. Legacy spring/friction
 # multipliers and the COM origin cannot be mapped without vehicle geometry.
 var handling := db.find_record("handling","IDAHO")
 arena.vehicle.profile = arena.vehicle.profile.duplicate()
 arena.vehicle.profile.mass = handling.mass
 arena.vehicle.mass = handling.mass
 arena.vehicle.profile.max_speed = handling.max_speed_kmh/3.6
 arena.vehicle.profile.steering_angle = deg_to_rad(handling.steering_degrees)
 arena.vehicle.profile.driven_front = handling.drive in ["F","4"]
 arena.vehicle.profile.driven_rear = handling.drive in ["R","4"]
 arena.transition.profile = arena.transition.profile.duplicate()
 arena.transition.profile.enter_seconds = lib.get_animation("CAR_getin_LHS").length
 arena.transition.profile.exit_seconds = lib.get_animation("CAR_getout_LHS").length
 for i in range(4):
  var ped: CharacterMotor = preload("res://scenes/character.tscn").instantiate()
  ped.name = "Pedestrian%d"%i
  ped.position = Vector3(-24+i*3,0.94,24)
  arena.add_child(ped)
  var stat: String = ["STAT_STREET_GUY","STAT_SENSIBLE_GIRL","STAT_OLD_GUY","STAT_TOUGH_GUY"][i]
  ped.configure_reference(db,stat,lib)
  var brain := PedBrain.new()
  brain.actor = ped
  brain.player = arena.actor
  var record := db.find_record("ped_stats",stat)
  brain.fear = record.fear
  brain.temper = record.temper
  brain.flee_distance = record.flee_distance
  brain.relationships = db.find_record("ped_types","CIVFEMALE" if "GIRL" in stat else "CIVMALE")
  brain.waypoints = PackedVector3Array([Vector3(-24+i*2,0.94,24),Vector3(-8+i*2,0.94,24),Vector3(-8+i*2,0.94,32),Vector3(-24+i*2,0.94,32)])
  ped.add_child(brain)
  arena.pedestrians.append(ped)
  arena.ped_brains.append(brain)
  var label := LabGeometry.label(ped,"Pedestrian %02d"%(i+1),Vector3(0,1.15,0),14)
  label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 arena.weapon.shot_fired.connect(func(origin: Vector3,_end: Vector3,_hit: bool):
  for brain in arena.ped_brains: brain.hear_shot(origin))
