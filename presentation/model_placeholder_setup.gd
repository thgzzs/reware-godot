class_name ModelPlaceholderSetup
extends RefCounted
static func apply_character(actor: CharacterMotor, assets: PlaceholderAssets) -> void:
 var packed := assets.scene(assets.character_scene)
 if packed==null or not actor.reference_enabled: return
 for child in actor.visual.get_children(): child.queue_free()
 var driver := SkinnedMotionVisual.new()
 driver.name = "SkinnedPresentation"
 driver.motion = actor.reference_motion
 driver.actions = actor.actions
 driver.position = assets.character_offset
 driver.add_child(packed.instantiate())
 actor.visual.add_child(driver)
 actor.reference_pose = driver
 driver.sample_pose()
 actor.set_meta("placeholder_model","player")
 var weapon_scene := assets.scene(assets.weapon_scene)
 if weapon_scene!=null:
  var hand := BoneAttachment3D.new()
  driver.skeleton.add_child(hand)
  hand.bone_name = assets.weapon_bone
  var weapon := EquippedWeaponVisual.new()
  weapon.actor = actor
  weapon.assets = assets
  hand.add_child(weapon)
static func apply_vehicle(car: DriveVehicle, assets: PlaceholderAssets) -> void:
 var packed := assets.scene(assets.vehicle_scene)
 if packed==null: return
 for name in ["Body","Windows","LampLeft","LampRight"]: car.get_node(name).hide()
 var model := packed.instantiate() as Node3D
 model.name = "VehiclePresentation"
 model.position = assets.vehicle_offset
 car.add_child(model)
 for pair in [[0,"door_lf_dummy"],[1,"door_rf_dummy"]]:
  var frame := model.find_child(pair[1],true,false) as Node3D
  if frame!=null:
   var door: VehicleDoor = car.doors[pair[0]]
   door.hinge_offset = car.to_local(frame.global_position)
   door.joint.position = door.hinge_offset
   door.global_transform = car.global_transform*Transform3D(Basis.IDENTITY,door.hinge_offset)
   door.attach_model(frame)
 var hull := car.get_node("Hull") as CollisionShape3D
 hull.shape = hull.shape.duplicate()
 (hull.shape as BoxShape3D).size = assets.vehicle_hull_size
 car.impact_probe.shape = hull.shape
 var seat := model.find_child("ped_frontseat",true,false) as Node3D
 if seat!=null:
  car.door_profile.seat_offset = car.to_local(seat.global_position)
  car.door_profile.seat_offset.x = -absf(car.door_profile.seat_offset.x)
 for mesh in car.find_children("*","MeshInstance3D",true,false):
  for surface in range(mesh.mesh.get_surface_count()):
   var material: StandardMaterial3D = mesh.mesh.surface_get_material(surface)
   if material==null: continue
   var channel: int = material.get_meta("vehicle_color_channel",0)
   if channel>0:
    var paint := material.duplicate() as StandardMaterial3D
    paint.albedo_color = assets.vehicle_primary if channel==1 else assets.vehicle_secondary
    mesh.set_surface_override_material(surface,paint)
 # Original wheel markers set the axle spacing; suspension calibration remains
 # a prototype. Keep the ray mount height so changing visuals does not fake
 # a mapping from a legacy spring coefficient to an SI force.
 for pair in [[0,"wheel_lf_dummy"],[1,"wheel_rf_dummy"],[2,"wheel_lb_dummy"],[3,"wheel_rb_dummy"]]:
  var marker := model.find_child(pair[1],true,false) as Node3D
  if marker!=null:
   var at := model.transform*marker.transform.origin
   car.mounts[pair[0]].x = at.x
   car.mounts[pair[0]].z = at.z
 # Visual geometry uses original frame transforms. The established physics tuning
 # remains independent until measured against source traces.
 var tire := assets.texture("tyre")
 for wheel in car.wheel_visuals:
  var mesh := wheel.get_child(0) as MeshInstance3D
  var material := StandardMaterial3D.new()
  material.albedo_texture = tire
  material.roughness = 1
  mesh.material_override = material
  var hub := MeshInstance3D.new()
  var quad := QuadMesh.new()
  quad.size = Vector2(0.50,0.50)
  hub.mesh = quad
  var hub_material := StandardMaterial3D.new()
  hub_material.albedo_texture = assets.texture("wheel")
  hub.material_override = hub_material
  wheel.add_child(hub)
  hub.position.x = -0.12 if wheel.position.x<0 else 0.12
  hub.rotation.y = -PI*0.5 if wheel.position.x<0 else PI*0.5
 car.set_meta("placeholder_model","idaho")
static func apply(arena: Node3D, assets: PlaceholderAssets) -> void:
 var shots := ShotPresentation.new()
 arena.add_child(shots)
 shots.configure(assets)
 arena.weapon.shot_fired.connect(shots.shot)
 apply_character(arena.actor,assets)
 for ped in arena.pedestrians: apply_character(ped,assets)
 apply_vehicle(arena.vehicle,assets)
 var prop := assets.scene(assets.prop_scene)
 if prop!=null:
  for at in [Vector3(4,0,7),Vector3(4,0,10)]:
   var body := StaticBody3D.new()
   arena.add_child(body)
   body.position = at
   body.add_child(prop.instantiate())
   var shape := CollisionShape3D.new()
   var box := BoxShape3D.new()
   box.size = Vector3(0.78,1.04,0.88)
   shape.shape = box
   shape.position.y = 0.52
   body.add_child(shape)
 if not assets.decorate_arena: return
 for pair in [["Ground","ground"],["Road","road"]]:
  var geometry := arena.get_node_or_null(pair[0])
  if geometry==null: continue
  var mesh: MeshInstance3D = geometry as MeshInstance3D
  if geometry is StaticBody3D:
   for child in geometry.get_children():
    if child is MeshInstance3D:
     mesh = child
     break
  apply_surface(mesh,assets.texture(pair[1]),Vector3(1,12,1) if pair[1]=="road" else Vector3(75,75,75))
 for i in range(4):
  var step := arena.get_node_or_null("Step%d"%i)
  if step!=null:
   for child in step.get_children():
    if child is MeshInstance3D: apply_surface(child,assets.texture("steps"),Vector3(2,2,2))
 for target in arena.targets:
  var face := target.get_node_or_null("Mesh/Bullseye") as MeshInstance3D
  if face!=null: apply_surface(face,assets.texture("target"),Vector3.ONE)
 # The existing graybox light was tuned for flat colors. Use a moderate shared
 # light level with the imported albedo textures; this is placeholder lighting.
 for child in arena.get_children():
  if child is DirectionalLight3D: child.light_energy = 0.8
  elif child is WorldEnvironment: child.environment.ambient_light_energy = 0.4
static func apply_surface(mesh: MeshInstance3D, texture: Texture2D, tiling: Vector3) -> void:
 if mesh==null or texture==null: return
 var material := StandardMaterial3D.new()
 material.albedo_texture = texture
 material.uv1_scale = tiling
 material.roughness = 1
 mesh.material_override = material

