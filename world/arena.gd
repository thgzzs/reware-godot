extends Node3D
## Composition root; owns wiring and explicit gameplay phase order only.
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
 build_world()
 actor = preload("res://scenes/character.tscn").instantiate()
 add_child(actor)
 actor.position = Vector3(-3,0.94,4)
 vehicle = preload("res://scenes/vehicle.tscn").instantiate()
 add_child(vehicle)
 vehicle.position = Vector3(1,0.90,0)
 weapon = WeaponController.new()
 weapon.profile = preload("res://tuning/weapon.tres")
 add_child(weapon)
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
 if DisplayServer.get_name()!="headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
  input_source.mouse_delta += event.relative
 if event.is_action_pressed("debug"): overlay.diagnostics = not overlay.diagnostics
 if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
 if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
  Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func _physics_process(dt: float) -> void:
 if not is_instance_valid(actor): return
 var start_us := Time.get_ticks_usec()
 var cmd := injected_command if test_mode else input_source.sample()
 if cmd.interact:
  if transition.state == "on_foot": transition.request_enter(nearest_vehicle())
  elif transition.state == "driving": transition.request_exit()
 transition.tick(dt)
 var driving := transition.state == "driving"
 actor.tick(cmd,rig.yaw,dt)
 if driving: vehicle.command(cmd)
 else: vehicle.park()
 var pivot := vehicle.global_position+Vector3.UP*0.8 if transition.state!="on_foot" else actor.global_position+Vector3.UP*0.55
 var exclude: Array[RID] = [actor.get_rid()]
 if transition.state!="on_foot": exclude.append(vehicle.get_rid())
 rig.tick(pivot,cmd,driving,exclude,dt)
 var muzzle := actor.global_position+Vector3.UP*0.35+Basis(Vector3.UP,rig.yaw)*Vector3(0.28,0,-0.48)
 weapon.tick(cmd,transition.state=="on_foot",get_world_3d().direct_space_state,rig.camera,muzzle,exclude,dt)
 vehicle.update_visuals(dt)
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
   if d<distance:
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
 environment.environment.ambient_light_energy = 0.7
 environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 add_child(environment)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-32,-30,0)
 sun.light_color = Color("ffe1bb")
 sun.light_energy = 1.6
 sun.shadow_enabled = true
 sun.directional_shadow_max_distance = 120
 add_child(sun)
 LabGeometry.box(self,Vector3(150,1,150),Vector3(0,-0.5,0),Color("687b7d"),true).name = "Ground"
 LabGeometry.box(self,Vector3(22,0.025,100),Vector3(18,0.015,0),Color("314550"))
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
