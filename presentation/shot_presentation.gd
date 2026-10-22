class_name ShotPresentation
extends Node3D
## Two reused sprites; presentation does not own hit detection or damage.
var flash := Sprite3D.new()
var impact := Sprite3D.new()
var flash_left := 0.0
var impact_left := 0.0
func configure(assets: PlaceholderAssets) -> void:
 for pair in [[flash,"muzzle_flash"],[impact,"impact"]]:
  var sprite: Sprite3D = pair[0]
  sprite.texture = assets.texture(pair[1])
  sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
  sprite.pixel_size = 0.008
  sprite.modulate.a = 0
  add_child(sprite)
func shot(origin: Vector3, end: Vector3, hit: bool) -> void:
 flash.global_position = origin
 flash_left = 0.045
 if hit:
  impact.global_position = end
  impact_left = 0.15
func _process(dt: float) -> void:
 flash_left = maxf(0,flash_left-dt)
 impact_left = maxf(0,impact_left-dt)
 flash.modulate.a = minf(1,flash_left/0.045)
 impact.modulate.a = minf(1,impact_left/0.15)
