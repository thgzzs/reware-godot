extends SceneTree
var arena: Node3D
var results: Array[Dictionary] = []
var failures := 0
var metrics := {}
func _initialize() -> void: run.call_deferred()
func check(label: String, condition: bool, value: Variant = null) -> void:
 results.append({"name":label,"passed":condition,"measured":value})
 if not condition: failures += 1
 print("PASS " if condition else "FAIL ",label," ",value)
func frames(count: int) -> void:
 for i in range(count):
  await physics_frame
  await process_frame
func test_skin() -> void:
 var visual: SkinnedMotionVisual = arena.actor.reference_pose
 var skeleton := visual.skeleton
 var mesh := visual.get_child(0).get_node("Geometry0") as MeshInstance3D
 if mesh==null or mesh.skin==null:
  check("character mesh has a native Skin",false)
  return
 check("native character uses real hierarchy and skin",skeleton.get_bone_count()==25 and mesh.skin.get_bind_count()==24,[skeleton.get_bone_count(),mesh.skin.get_bind_count()])
 var max_error := 0.0
 for i in range(mesh.skin.get_bind_count()):
  var identity := skeleton.get_bone_global_rest(mesh.skin.get_bind_bone(i))*mesh.skin.get_bind_pose(i)
  max_error = maxf(max_error,identity.origin.length())
  for axis in range(3): max_error = maxf(max_error,(identity.basis[axis]-Basis.IDENTITY[axis]).length())
 check("all source inverse binds cancel rest transforms",max_error<0.0001,max_error)
 var total_vertices := 0
 var weights_valid := true
 for surface in range(mesh.mesh.get_surface_count()):
  var arrays := mesh.mesh.surface_get_arrays(surface)
  var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
  var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
  total_vertices += vertices.size()
  for i in range(vertices.size()):
   var sum := 0.0
   for j in range(4):
    var weight := weights[i*4+j]
    sum += weight
    if not is_finite(weight) or weight<0 or bones[i*4+j]>=24: weights_valid = false
   if absf(sum-1)>0.0001: weights_valid = false
 check("all native skin weights and palette indices valid",weights_valid,total_vertices)
 arena.actor.reference_motion.preview_clip = "IDLE_stance"
 arena.actor.reference_motion.preview_time = 0
 arena.actor.reference_motion.preview_playing = false
 visual.sample_pose()
 var minimum := Vector3(INF,INF,INF)
 var maximum := Vector3(-INF,-INF,-INF)
 # CPU evaluation of the actual loaded native mesh+skin, independent of rendering.
 for surface in range(mesh.mesh.get_surface_count()):
  var arrays := mesh.mesh.surface_get_arrays(surface)
  var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
  var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
  for i in range(vertices.size()):
   var p := Vector3.ZERO
   for j in range(4):
    var bind := bones[i*4+j]
    p += (skeleton.get_bone_global_pose(mesh.skin.get_bind_bone(bind))*mesh.skin.get_bind_pose(bind)*vertices[i])*weights[i*4+j]
   minimum = minimum.min(p)
   maximum = maximum.max(p)
 check("idle skin stands upright at original scale",maximum.y-minimum.y>1.7 and maximum.y-minimum.y<2.0 and maximum.x-minimum.x<0.9,{"minimum":minimum,"maximum":maximum})
 check("root locomotion translation is not applied twice",Vector2(skeleton.get_bone_pose_position(skeleton.find_bone("Root")).x,skeleton.get_bone_pose_position(skeleton.find_bone("Root")).z).length()<0.00001)
 arena.actor.reference_motion.preview_clip = ""
 check("player and NPCs share skinned presentation and actor components",arena.pedestrians.all(func(p: CharacterMotor): return p.reference_pose is SkinnedMotionVisual and p.get_script()==arena.actor.get_script() and p.reference_pose.skeleton!=skeleton))
 check("pistol is bound to the actual right hand",skeleton.find_child("@BoneAttachment3D@*",false,false)!=null or skeleton.get_children().any(func(n: Node): return n is BoneAttachment3D and n.bone_name=="R Hand"))
 var car: Node3D = arena.vehicle.get_node("VehiclePresentation")
 check("Idaho retains wheel door and seat markers",car.find_child("wheel_lf_dummy",true,false)!=null and car.find_child("door_lf_dummy",true,false)!=null and car.find_child("ped_frontseat",true,false)!=null)
 check("damaged and low-detail variants are hidden",not car.find_child("chassis_vlo",true,false).visible and not car.find_child("bonnet_hi_dam",true,false).visible)
 check("axle spacing derives from original wheel markers",absf(arena.vehicle.mounts[0].z+1.692)<0.002 and absf(arena.vehicle.mounts[2].z-1.693)<0.002,arena.vehicle.mounts)
 check("vehicle hull covers placeholder body length",arena.vehicle.get_node("Hull").shape.size.z>=5.4)
func test_layout() -> void:
 for dimensions in [Vector2i(640,360),Vector2i(1024,768),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(3440,1440),Vector2i(3840,2160),Vector2i(1080,1920)]:
  root.size = dimensions
  await frames(2)
  var logical := root.get_visible_rect().size
  var layout := DisplayController.hud_layout(logical)
  var bounds := Rect2(Vector2.ZERO,logical)
  var valid := true
  for key in ["status","context","ammo","radar","modal"]:
   if not bounds.encloses(layout[key]): valid = false
  if layout.status.intersects(layout.context) or layout.ammo.intersects(layout.radar): valid = false
  var ray: Vector3 = arena.rig.camera.project_ray_normal(logical*0.5)
  var error: float = ray.distance_to(-arena.rig.camera.global_basis.z)
  check("HUD and center ray adapt to %dx%d"%[dimensions.x,dimensions.y],valid and error<0.0001,{"logical":logical,"ray_error":error})
 check("camera preserves vertical FOV on resize",arena.rig.camera.keep_aspect==Camera3D.KEEP_HEIGHT)
 var display: DisplayController = arena.display_controller
 display.set_render_scale(0.5,false)
 var logical_before := root.get_visible_rect().size
 display.set_ui_scale(1.4)
 await frames(2)
 check("3D scale and UI scale are independent",is_equal_approx(root.scaling_3d_scale,0.5) and is_equal_approx(root.content_scale_factor,1.4) and root.get_visible_rect().size!=logical_before)
 display.set_ui_scale(1.0)
 display.set_render_scale(1.0,false)
 arena.overlay.toggle_settings()
 var firing := GameplayCommand.new(); firing.fire = true
 arena.injected_command = firing
 var shots: int = arena.weapon.shots
 await frames(30)
 check("display menu blocks firing and movement commands",arena.weapon.shots==shots and arena.actor.drive_velocity.length()<0.01)
 arena.overlay.toggle_settings()
 await frames(1)
 check("closing display menu resumes weapon input",arena.weapon.shots>shots)
 arena.injected_command = GameplayCommand.new()
 display.set_adaptive(true)
 display.set_render_scale(1.0,false)
 for i in range(80): display.sample_frame(1.0/30.0)
 check("adaptive scale falls after sustained slow frames",display.current_scale<1.0,display.current_scale)
 var after_slow := display.current_scale
 for i in range(8): display.sample_frame(1.0/120.0)
 check("adaptive cooldown prevents immediate oscillation",display.current_scale==after_slow)
 for i in range(2000): display.sample_frame(1.0/120.0)
 check("adaptive scale recovers and remains bounded",display.current_scale>after_slow and display.current_scale<=1.0,display.current_scale)
 for i in range(3000): display.sample_frame(1.0/20.0)
 check("adaptive scale respects minimum",is_equal_approx(display.current_scale,display.profile.minimum_scale),display.current_scale)
 display.set_adaptive(false)
 display.set_render_scale(1.0,false)
func run() -> void:
 arena = preload("res://scenes/arena.tscn").instantiate()
 arena.test_mode = true
 root.add_child(arena)
 await frames(60)
 check("imported car settles at its spawn",arena.vehicle.position.distance_to(Vector3(1,0.9,0))<1.0 and arena.vehicle.linear_velocity.length()<1.0,{"position":arena.vehicle.position,"velocity":arena.vehicle.linear_velocity})
 test_skin()
 await test_layout()
 var pose_samples := GameplayTelemetry.new()
 for i in range(180):
  await frames(1)
  pose_samples.record(arena.actor.reference_pose.sample_us)
 metrics.player_pose_cpu = pose_samples.summary()
 metrics.player_pose_cpu.scope = "one player's SkinnedMotionVisual.sample_pose CPU time only; excludes other actors, Jolt and rendering"
 metrics.scope = "Headless Jolt plus CPU native skin evaluation and layout/viewport API tests. No desktop or GPU timing equivalence."
 var report := {"assertions":results.size(),"failures":failures,"results":results,"metrics":metrics,"engine":Engine.get_version_info().string}
 var file := FileAccess.open("res://tests/presentation_results.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 print("RESULT presentation ",results.size()," assertions / ",failures," failures")
 arena.queue_free()
 await process_frame
 quit(1 if failures>0 else 0)
