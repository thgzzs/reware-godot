class_name VehicleDamageVisual
extends Node3D
var car: DriveVehicle
var smoke := CPUParticles3D.new()
var flame := CPUParticles3D.new()
var scorch:=VehicleScorch.new()
func configure(vehicle: DriveVehicle) -> void:
 car = vehicle
 scorch.car=car
 position = Vector3(0,0.5,-1.5)
 for emitter in [smoke,flame]:
  emitter.emitting = false
  emitter.amount = 18
  emitter.lifetime = 1.2
  emitter.local_coords = false
  emitter.direction = Vector3.UP
  emitter.spread = 18
  emitter.initial_velocity_min = 0.5
  emitter.initial_velocity_max = 1.6
  emitter.gravity = Vector3(0,0.3,0)
  emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
  emitter.emission_box_extents = Vector3(0.35,0.05,0.22)
  var mesh := QuadMesh.new()
  mesh.size = Vector2(0.65,0.65) if emitter==smoke else Vector2(0.28,0.65)
  emitter.mesh = mesh
  var soft := GradientTexture2D.new()
  soft.width = 64;soft.height = 64
  soft.fill = GradientTexture2D.FILL_RADIAL
  soft.fill_from = Vector2(0.5,0.5);soft.fill_to=Vector2(0.5,0)
  soft.gradient = Gradient.new()
  soft.gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,0)])
  var material := StandardMaterial3D.new()
  material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  material.albedo_texture = soft
  material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
  material.vertex_color_use_as_albedo = true
  material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  emitter.material_override = material
  var colors := Gradient.new()
  colors.offsets = PackedFloat32Array([0.0,0.15,0.65,1.0])
  colors.colors = PackedColorArray([Color(0.1,0.1,0.12,0),Color(0.14,0.14,0.16,0.5),Color(0.16,0.16,0.18,0.35),Color(0.2,0.2,0.2,0)]) if emitter==smoke else PackedColorArray([Color(1,0.8,0.1,0),Color(1,0.75,0.05,0.8),Color(1,0.16,0.01,0.65),Color(0.4,0.05,0.01,0)])
  emitter.color_ramp = colors
  add_child(emitter)
 car.damage.state_changed.connect(update_state)
func update_state(state: String) -> void:
 if state=="destroyed":scorch.apply()
 elif state=="healthy":scorch.restore()
 smoke.emitting = state in ["smoking","burning","destroyed"]
 flame.emitting = state=="burning"
