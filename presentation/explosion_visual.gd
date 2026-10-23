class_name ExplosionVisual
extends MeshInstance3D
var age := 0.0
func _ready() -> void:
 var sphere := SphereMesh.new()
 sphere.radius = 0.5
 sphere.height = 1
 sphere.radial_segments = 16
 sphere.rings = 8
 mesh = sphere
 var material := StandardMaterial3D.new()
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 material.albedo_color = Color(1,0.45,0.03,0.7)
 material_override = material
func _process(dt: float) -> void:
 age += dt
 scale = Vector3.ONE*(1+age*10)
 (material_override as StandardMaterial3D).albedo_color.a = maxf(0,0.7-age)
 if age>0.7: queue_free()
