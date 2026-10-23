extends SceneTree
## Exercises the retained native skin, source clips and door model attachment.
var arena: Node3D
var results: Array[Dictionary] = []
var failures := 0
var metrics := {}
func _initialize() -> void: run.call_deferred()
func frames(count: int, command: GameplayCommand = null) -> void:
 arena.injected_command = command if command!=null else GameplayCommand.new()
 for i in range(count):
  await physics_frame
  await process_frame
func check(label: String, condition: bool, measured: Variant = null) -> void:
 results.append({"name":label,"passed":condition,"measured":measured})
 if not condition: failures += 1
 print("PASS " if condition else "FAIL ",label," ",measured)
func skin_bounds(driver: SkinnedMotionVisual) -> AABB:
 var mesh := driver.get_child(0).get_node("Geometry0") as MeshInstance3D
 var minimum := Vector3(INF,INF,INF)
 var maximum := Vector3(-INF,-INF,-INF)
 for surface in range(mesh.mesh.get_surface_count()):
  var arrays := mesh.mesh.surface_get_arrays(surface)
  var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
  var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
  for i in range(vertices.size()):
   var p := Vector3.ZERO
   for j in range(4):
    var bind := bones[i*4+j]
    p += driver.skeleton.get_bone_global_pose(mesh.skin.get_bind_bone(bind))*mesh.skin.get_bind_pose(bind)*vertices[i]*weights[i*4+j]
   p = driver.global_transform*p
   minimum = minimum.min(p); maximum = maximum.max(p)
 return AABB(minimum,maximum-minimum)
func run() -> void:
 if not ImportedAssetSetup.available():
  push_error("Native assets required"); quit(2); return
 arena = preload("res://scenes/arena.tscn").instantiate()
 arena.test_mode = true
 root.add_child(arena)
 await frames(90)
 var actor: CharacterMotor = arena.actor
 var visual: SkinnedMotionVisual = actor.reference_pose
 var motion: ReferenceMotion = actor.reference_motion
 var gun: WeaponController = actor.weapon
 var car: DriveVehicle = arena.vehicle
 actor.reset_at(Vector3(-28,0.94,40))
 await frames(20)
 var walking := GameplayCommand.new(); walking.move = Vector2(0,-1); walking.walk = true
 await frames(75,walking)
 visual.sample_pose(0.2)
 var thigh := visual.skeleton.find_bone("R Thigh")
 var before := visual.skeleton.get_bone_pose_rotation(thigh)
 actor.actions.aim_weight = 1
 visual.sample_pose(0.2)
 check("native aim mask preserves the moving thigh pose",visual.skeleton.get_bone_pose_rotation(thigh).angle_to(before)<0.002)
 var hand := visual.skeleton.find_bone("R Hand")
 actor.actions.has_aim_target = false
 actor.actions.upper_allowed = true
 for pitch in [-0.4,0.0,0.35]:
  actor.actions.aim_pitch = pitch
  visual.sample_pose(0.2)
  var expected := Vector3(0,-sin(pitch),-cos(pitch))
  var error := visual.skeleton.get_bone_global_pose(hand).basis.x.normalized().angle_to(expected)
  check("native gun hand follows aim pitch %.2f"%pitch,error<0.03,error)
 var aimed_bounds := skin_bounds(visual)
 check("native aimed skin stays finite and within human scale",aimed_bounds.position.is_finite() and aimed_bounds.size.is_finite() and aimed_bounds.size.length()<3.5,aimed_bounds.size)
 for slot in range(gun.inventory.size()):
  gun.equip_slot(slot)
  actor.reset_at(Vector3(-28,0.94,40))
  await frames(20)
  var sprint := GameplayCommand.new(); sprint.move = Vector2(0,-1); sprint.sprint = true
  await frames(75,sprint)
  check("native sprint works with "+gun.profile.display_name,motion.clip=="sprint_civi" and actor.drive_velocity.length()>3,motion.clip)
  var pose := actor.weapon_muzzle.get_parent() as EquippedWeaponVisual
  var visible_models := 0
  for model in pose.models.values():
   if model.visible: visible_models += 1
  check("weapon visual selection remains unique in slot %d"%slot,visible_models==1)
 actor.reset_at(Vector3(-28,0.94,40))
 await frames(30)
 gun.equip_slot(0)
 actor.health.receive(1000)
 await frames(ceili(motion.duration(actor.actions.life_clip)*60)+20)
 visual.sample_pose(0.2)
 var corpse := skin_bounds(visual)
 var frozen := visual.skeleton.get_bone_pose_rotation(thigh)
 await frames(45)
 visual.sample_pose(0.2)
 metrics.death_skin = {"minimum":corpse.position,"size":corpse.size,"clip":actor.actions.life_clip,"body_y":actor.global_position.y}
 check("native death reaches its terminal pose once",actor.actions.life=="dead" and visual.skeleton.get_bone_pose_rotation(thigh).angle_to(frozen)<0.002,metrics.death_skin)
 check("native death mesh rests above the arena floor",corpse.position.y>-0.03 and corpse.position.y<0.06 and corpse.size.y<1.1,metrics.death_skin)
 actor.respawn(Vector3(-3,0.94,4))
 car.reset_at(Vector3(18,0.9,25))
 await frames(120)
 for side in range(2):
  var door: VehicleDoor = car.doors[side]
  var frame := door.find_child("door_lf_dummy" if side==0 else "door_rf_dummy",true,false) as Node3D
  check("native door frame belongs to physical hinge %d"%side,frame!=null and not door.panel.visible)
  var local_rest := frame.transform
  car.set_door_open(side,true)
  await frames(70)
  check("native door moves with its physical body %d"%side,absf(door.angle)>0.5 and frame.transform.is_equal_approx(local_rest),door.angle)
  car.set_door_open(side,false)
  await frames(160)
  check("native door returns to latch %d"%side,door.latched and frame.transform.is_equal_approx(local_rest))
 var seat: VehicleTransition = arena.transition
 actor.reset_at(car.approach_position())
 await frames(25)
 check("native model entry can reserve the seat",seat.request_enter(car))
 await frames(1)
 check("vehicle entry holsters the equipped weapon",not actor.weapon_muzzle.get_parent().visible)
 await frames(ceili(seat.profile.enter_seconds*60)+3)
 check("native model entry commits after all stages",seat.state=="driving" and car.driver==actor)
 check("native model exit can begin safely",seat.request_exit())
 await frames(ceili(seat.profile.exit_seconds*60)+3)
 check("native model exit restores standing actor and gun",seat.state=="on_foot" and actor.control_enabled and is_instance_valid(actor.weapon_muzzle) and actor.weapon_muzzle.get_parent().visible)
 var report := {"engine":Engine.get_version_info().string,"backend":"Jolt Physics","assertions":results.size(),"failures":failures,"results":results,"metrics":metrics,"source_assets_reconverted":false,"reference_runtime_parity":false}
 var output := FileAccess.open("res://tests/native_action_results.json",FileAccess.WRITE)
 output.store_string(JSON.stringify(report,"  ")); output.close()
 print("RESULT native actions ",results.size()," assertions / ",failures," failures")
 arena.queue_free(); await process_frame
 quit(1 if failures else 0)
