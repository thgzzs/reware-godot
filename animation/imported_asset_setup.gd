class_name ImportedAssetSetup
extends RefCounted
const LIBRARY_PATH := "res://assets/converted/ped_library.res"
const DATABASE_PATH := "res://assets/converted/gameplay_database.tres"
static func available() -> bool:
 return ResourceLoader.exists(LIBRARY_PATH) and ResourceLoader.exists(DATABASE_PATH)
static func weapon_profile(record: Dictionary, prototype: WeaponProfile, library:AnimationLibrary=null) -> WeaponProfile:
 var result: WeaponProfile = prototype.duplicate()
 result.id = String(record.name).to_lower()
 result.kind = "melee" if record.get("fire_type","INSTANT_HIT")=="MELEE" else "hitscan"
 result.source_model_id = int(record.get("model_ids",[-1,-1])[0])
 result.model_scene = "" if result.id=="unarmed" else "res://assets/converted/models/"+result.id+".scn"
 result.two_handed = result.kind!="melee" and (int(record.get("flags",0))&0x80)==0
 result.display_name = record.name
 result.interval = record.firing_rate_ms/1000.0
 var frames: Array = record.get("animation_frames",[])
 var name: String = String(record.name).to_lower()
 var shotgun := "shotgun" in name or name in ["spas12","stubby"]
 # WeaponInfo.cpp converts 30 Hz frames and derives non-shotgun cadence.
 if frames.size()>=2 and frames[1]<98 and not shotgun and name!="flamethrower":
  result.interval = maxf(0.01,(frames[1]-frames[0])*0.03)
 result.reload_seconds = record.reload_ms/1000.0
 result.magazine_size = int(record.clip_size)
 result.damage = record.damage/6.0 if shotgun else record.damage
 result.range_meters = record.range
 result.animation_group = record.animation_group
 result.heavy = name in ["m4","ruger","m60","minigun"]
 result.pellets = 6 if shotgun else 1
 if frames.size()>2:result.fire_frame_seconds=float(frames[2])*0.03
 var catalog:WeaponActionCatalog=preload("res://tuning/weapon_actions.tres")
 if result.two_handed:result.pose=catalog.two_hand_pistol_pose if result.id=="python" else catalog.long_gun_pose
 result.animation_group=catalog.animation_groups.get(result.id,result.animation_group)
 var melee_sets:=catalog.melee_sets
 result.muzzle_local=catalog.muzzle_offsets.get(result.id,result.muzzle_local)
 result.melee_tip=catalog.melee_tips.get(result.id,result.melee_tip)
 if melee_sets.has(result.id):result.melee_clips=melee_sets[result.id]
 result.melee_reach=0.7 if catalog.long_reach.has(result.id) else 0.3
 result.melee_radius=0.24
 if result.id in ["shotgun","stubbyshotgun"] and frames.size()>=2:
  result.native_fire_recovery=maxf(result.interval,(float(frames[1])-float(frames[0]))*0.03)
  result.interval=maxf(result.interval,result.native_fire_recovery)
  result.reload_seconds=maxf(result.reload_seconds,result.native_fire_recovery)
 if library!=null and result.kind!="melee":
  for clip in library.get_animation_list():
   if String(clip).to_lower() in [result.animation_group.to_lower()+"_reload",result.animation_group.to_lower()+"_load"]:
    result.reload_seconds=maxf(result.reload_seconds,library.get_animation(clip).length)
    break
 return result
static func apply(arena: Node3D) -> void:
 var lib: AnimationLibrary = load(LIBRARY_PATH)
 var db: ImportedGameplayDatabase = load(DATABASE_PATH)
 arena.reference_library = lib
 arena.reference_database = db
 arena.actor.configure_reference(db,"STAT_PLAYER",lib)
 var loadout: Array[WeaponProfile] = []
 for selected in arena.weapon.loadout.reference_weapons:
  for record in db.weapons:
   if String(record.name).nocasecmp_to(selected)==0:
    var item := weapon_profile(record,arena.weapon.profile,lib)
    if item.id=="unarmed" or ResourceLoader.exists(item.model_scene): loadout.append(item)
 if not loadout.is_empty(): arena.weapon.configure_loadout(loadout)
 for name in ["StdPunch","Jab","PunchHook","LongKick"]:
  for move in db.fight_moves:
   if move.name==name: arena.weapon.melee.moves.append(move)
 # Only dimensionally understood fields are applied. Legacy spring/friction
 # multipliers and the COM origin cannot be mapped without vehicle geometry.
 var handling := db.find_record("handling","IDAHO")
 HandlingDataMapper.apply(arena.vehicle,handling)
 arena.transition.profile = arena.transition.profile.duplicate()
 arena.transition.profile.enter_open_seconds = lib.get_animation("CAR_open_LHS").length if lib.has_animation("CAR_open_LHS") else 0.35
 arena.transition.profile.enter_close_seconds = lib.get_animation("CAR_closedoor_LHS").length if lib.has_animation("CAR_closedoor_LHS") else 0.25
 arena.transition.profile.exit_close_seconds = lib.get_animation("CAR_close_LHS").length if lib.has_animation("CAR_close_LHS") else 0.25
 arena.transition.profile.enter_seconds = arena.transition.profile.enter_open_seconds+lib.get_animation("CAR_getin_LHS").length+arena.transition.profile.enter_close_seconds
 arena.transition.profile.exit_seconds = lib.get_animation("CAR_getout_LHS").length+arena.transition.profile.exit_close_seconds
 for i in range(4):
  var ped: CharacterMotor = preload("res://scenes/character.tscn").instantiate()
  ped.name = "Pedestrian%d"%i
  ped.position = Vector3(-24+i*3,0.94,24)
  arena.add_child(ped)
  var stat: String = ["STAT_STREET_GUY","STAT_SENSIBLE_GIRL","STAT_OLD_GUY","STAT_TOUGH_GUY"][i]
  ped.configure_reference(db,stat,lib)
  var unarmed := db.find_record("weapons","Unarmed")
  if not unarmed.is_empty(): ped.weapon.configure_loadout([weapon_profile(unarmed,ped.weapon.profile,lib)])
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
 if arena.enable_vehicle_fixtures:
  VehicleFactory.spawn(arena,preload("res://tuning/front_drive_fixture.tres"),db,Vector3(18,0.9,32))
  VehicleFactory.spawn(arena,preload("res://tuning/all_drive_fixture.tres"),db,Vector3(25,0.9,32))
 if arena.enable_vehicle_fixtures:
  for row in [["pcj600",Vector3(10,0.7,14)],["sanchez",Vector3(13,0.7,14)],["faggio",Vector3(16,0.7,14)],["freeway",Vector3(19,0.7,14)]]:
   VehicleFactory.spawn(arena,load("res://tuning/"+row[0]+".tres"),db,row[1])
 arena.weapon.shot_fired.connect(func(origin: Vector3,_end: Vector3,_hit: bool):
  for brain in arena.ped_brains: brain.hear_shot(origin))

