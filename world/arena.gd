extends Node3D
## Composition root; owns wiring and explicit gameplay phase order only.
var enable_reference_assets := true
var enable_vehicle_fixtures := true
var enable_model_placeholders := true
var placeholder_assets: PlaceholderAssets = preload("res://tuning/placeholder_assets.tres")
var display_controller: DisplayController
var reference_library: AnimationLibrary
var reference_database: ImportedGameplayDatabase
var pedestrians: Array[CharacterMotor] = []
var ped_brains: Array[PedBrain] = []
var animation_browser: ImportedAnimationBrowser
var actor: CharacterMotor
var vehicle: DriveVehicle
var rig: FollowCameraRig
var weapon: WeaponController
var transition: VehicleTransition
var overlay: LabOverlay
var targets: Array[DamageReceiver] = []
var input_source := LocalInputSource.new()
var telemetry := GameplayTelemetry.new()
var test_mode := false
var injected_command := GameplayCommand.new()
var last_tick_us := 0.0
var tick_number := 0
func _ready() -> void:
	var version := Engine.get_version_info()
	if version.major!=4 or version.minor!=7 or version.patch!=2 or version.status!="stable":
		push_error("Requires exactly Godot 4.7.2 Stable; refusing a different engine")
		get_tree().quit(2)
		return
	if ProjectSettings.get_setting("physics/3d/physics_engine")!="Jolt Physics":
		push_error("Jolt Physics is required")
		get_tree().quit(2)
		return
	input_source.install()
	display_controller = DisplayController.new()
	display_controller.persist_settings = not test_mode
	add_child(display_controller)
	build_world()
	actor = preload("res://scenes/character.tscn").instantiate()
	actor.position = Vector3(-3,0.94,4)
	add_child(actor)
	vehicle = preload("res://scenes/vehicle.tscn").instantiate()
	vehicle.position = Vector3(1,0.90,0)
	add_child(vehicle)
	weapon = actor.weapon
	transition = VehicleTransition.new()
	transition.profile = preload("res://tuning/interaction.tres")
	transition.actor = actor
	add_child(transition)
	rig = FollowCameraRig.new()
	rig.profile = preload("res://tuning/camera.tres")
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.near = 0.08
	rig.add_child(camera)
	add_child(rig)
	weapon.recoil.connect(rig.add_recoil)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	overlay = LabOverlay.new()
	overlay.arena = self
	canvas.add_child(overlay)
	weapon.shot_fired.connect(overlay.on_shot)
	if enable_reference_assets and ImportedAssetSetup.available():
		ImportedAssetSetup.apply(self)
		if enable_model_placeholders: ModelPlaceholderSetup.apply(self,placeholder_assets)
		if actor.reference_pose is SkinnedMotionVisual: actor.reference_pose.set_process(false)
		animation_browser = ImportedAnimationBrowser.new()
		animation_browser.actor = actor
		animation_browser.database = reference_database
		canvas.add_child(animation_browser)
	if DisplayServer.get_name()!="headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			overlay.controls_visible = not overlay.controls_visible
			overlay.diagnostics = false
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F2:
			overlay.toggle_settings()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F4 and is_instance_valid(animation_browser):
		if overlay.settings.visible: overlay.toggle_settings()
		animation_browser.toggle()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input_source.mouse_delta += event.relative
	if event.is_action_pressed("debug"):
		overlay.diagnostics = not overlay.diagnostics
		overlay.controls_visible = false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not overlay.settings.visible and (not is_instance_valid(animation_browser) or not animation_browser.visible):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func _physics_process(dt: float) -> void:
	if not is_instance_valid(actor): return
	var start_us := Time.get_ticks_usec()
	var cmd := injected_command if test_mode else input_source.sample()
	if overlay.settings.visible or (is_instance_valid(animation_browser) and animation_browser.visible) or (not test_mode and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED):
		cmd = GameplayCommand.new()
		input_source.mouse_delta = Vector2.ZERO
	if cmd.repair_vehicle and transition.state=="on_foot" and actor.control_enabled:
		var nearest := nearest_vehicle()
		if nearest!=null and nearest.global_position.distance_to(actor.global_position)<4.5 and nearest.linear_velocity.length()<0.5:
			nearest.damage.repair()
			if nearest.global_basis.y.dot(Vector3.UP)<0.7: nearest.reset_at(Vector3(nearest.global_position.x,0.9,nearest.global_position.z))
	if cmd.interact:
		if transition.state == "on_foot": transition.request_enter(nearest_vehicle(),cmd.walk)
		elif transition.state in ["driving","passenger"]: transition.request_exit()
	if cmd.respawn and actor.health.health<=0 and transition.state=="on_foot":
		actor.respawn(Vector3(-3,0.94,4))
	if cmd.switch_seat: transition.request_switch_driver()
	rig.read_look(cmd)
	transition.tick(dt)
	var driving := transition.state == "driving"
	var armed := transition.state=="on_foot" and actor.control_enabled and actor.health.health>0
	weapon.advance(cmd,armed,dt)
	actor.actions.aim_pitch = rig.pitch
	actor.tick(cmd,rig.yaw,dt)
	weapon.melee.resolve_spatial_hits()
	var active_car: DriveVehicle = transition.vehicle if is_instance_valid(transition.vehicle) else vehicle
	for child in get_children():
		if child is DriveVehicle:
			if driving and child==active_car: child.command(cmd,"player")
			elif not is_instance_valid(child.driver) and child.control_owner not in ["external","coasting"]: child.park()
	rig.vehicle_basis = active_car.global_basis
	rig.vehicle_origin = active_car.global_position
	var pivot := active_car.global_position+Vector3.UP*0.8 if transition.state!="on_foot" else actor.global_position+Vector3.UP*(0.55-actor.stance.profile.camera_drop if actor.stance.crouched else 0.55)
	var exclude: Array[RID] = [actor.get_rid()]
	if transition.state!="on_foot": exclude.append(active_car.get_rid())
	rig.tick(pivot,cmd,transition.state!="on_foot",exclude,dt)
	actor.actions.aim_target = AimSolution.camera_target(get_world_3d().direct_space_state,rig.camera,weapon.profile.range_meters,exclude,actor.global_position+Vector3.UP*0.35)
	actor.actions.has_aim_target = true
	if actor.reference_pose is SkinnedMotionVisual and not actor.reaction_body.active:
		actor.reference_pose.sample_pose(dt)
		actor.reference_pose.skeleton.force_update_all_bone_transforms()
	var muzzle := actor.global_position+Vector3.UP*0.35+Basis(Vector3.UP,rig.yaw)*Vector3(0.28,0,-0.48)
	if is_instance_valid(actor.weapon_muzzle): muzzle = actor.weapon_muzzle.global_position
	if armed and actor.can_use_weapon(): weapon.try_fire(cmd,get_world_3d().direct_space_state,rig.camera,muzzle,exclude)
	if actor.global_position.y < -15 and transition.state == "on_foot": actor.reset_at(Vector3(-3,1,4))
	last_tick_us = Time.get_ticks_usec()-start_us
	telemetry.record(last_tick_us)
	tick_number += 1
func nearest_vehicle() -> DriveVehicle:
	# Registry boundary: adding vehicle types requires no controller changes.
	var best: DriveVehicle = null
	var distance := INF

	for child in get_children():
		if child is DriveVehicle:
			var d: float = actor.global_position.distance_squared_to(child.global_position)
			if d < distance:
				distance = d
				best = child

	return best
func build_world() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("638593")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("badce3")
	environment.environment.ambient_light_energy = placeholder_assets.ambient_light_energy
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32,-30,0)
	sun.light_color = Color("ffe1bb")
	sun.light_energy = placeholder_assets.directional_light_energy
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120
	add_child(sun)
	LabGeometry.box(self,Vector3(150,1,150),Vector3(0,-0.5,0),Color("687b7d"),true).name = "Ground"
	LabGeometry.box(self,Vector3(22,0.025,100),Vector3(18,0.015,0),Color("314550")).name = "Road"
	for z in range(-45,49,6):
		LabGeometry.box(self,Vector3(0.15,0.02,2.5),Vector3(18,0.04,z),Color("ded3af"))
	for x in [7.4,28.6]:
		LabGeometry.box(self,Vector3(0.15,0.02,100),Vector3(x,0.04,0),Color("cad8d5"))
	for x in [-4,0,4]:
		var target: DamageReceiver = preload("res://scenes/target.tscn").instantiate()
		target.position = Vector3(x,1.0,-11)
		add_child(target)
		targets.append(target)
		LabGeometry.box(self,Vector3(2.3,0.08,2.8),Vector3(x,0.04,-11),Color("485b61"))
	LabGeometry.box(self,Vector3(15,3.5,0.7),Vector3(0,1.75,-14),Color("283d49"),true)
	LabGeometry.label(self,"02 / TARGET RANGE",Vector3(0,3.5,-13.5),38)
	LabGeometry.label(self,"H A R B O R",Vector3(-13,5.8,-18),90)
	LabGeometry.box(self,Vector3(10,5,7),Vector3(-15,2.5,-21),Color("8d9993"),true)
	LabGeometry.box(self,Vector3(8,7,5),Vector3(-23,3.5,-25),Color("bcaa94"),true)
	LabGeometry.box(self,Vector3(7,4,6),Vector3(0,2,-25),Color("647f88"),true)
	for x in range(-18,-10,2):
		LabGeometry.box(self,Vector3(0.9,1.0,0.03),Vector3(x,3.0,-17.47),Color("2f535f"))
	for z in [-35,-22,-9,4,17,30,43]:
		LabGeometry.box(self,Vector3(0.15,5.5,0.15),Vector3(32,2.75,z),Color("344a55"))
		LabGeometry.box(self,Vector3(1.7,0.12,0.65),Vector3(31.25,5.5,z),Color("e9d7ad"))
	LabGeometry.label(self,"03 / DRIVE",Vector3(18,1.5,-22),40)
	# Measurement fixtures: low steps, passable ramp, steep ramp, wall, ceiling.
	for i in range(4):
		LabGeometry.box(self,Vector3(3,(i+1)*0.20,1),Vector3(-10,(i+1)*0.10,-i),Color("afbaad"),true).name = "Step%d"%i
	LabGeometry.label(self,"01 / TRAVERSE",Vector3(-10,2.7,-3),32)
	var ramp := LabGeometry.box(self,Vector3(3,0.25,6),Vector3(-16,0.75,4),Color("819996"),true)
	ramp.rotation.x = deg_to_rad(15)
	var steep := LabGeometry.box(self,Vector3(3,0.25,5),Vector3(-21,1.9,4),Color("bd926e"),true)
	steep.rotation.x = deg_to_rad(55)
	LabGeometry.box(self,Vector3(4,3,0.4),Vector3(-8,1.5,14),Color("516c76"),true).name = "TestWall"
	LabGeometry.box(self,Vector3(4,0.25,4),Vector3(-15,2.35,14),Color("516c76"),true).name = "LowCeiling"
	for x in [-34,38]:
		LabGeometry.box(self,Vector3(0.8,1.0,100),Vector3(x,0.5,0),Color("748e8b"),true)

