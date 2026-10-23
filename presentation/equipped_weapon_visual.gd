class_name EquippedWeaponVisual
extends Node3D
## No firearm family substitution: each profile resolves its exact model scene.
var actor: CharacterMotor
var assets: PlaceholderAssets
var models := {}
func _ready() -> void:
 for item in actor.weapon.inventory:
  var profile: WeaponProfile = item.profile
  var packed := assets.scene(profile.model_scene) if not profile.model_scene.is_empty() else null
  var model := packed.instantiate() as Node3D if packed!=null else Node3D.new()
  model.name = profile.id
  model.position = assets.weapon_offset
  model.rotation_degrees = assets.weapon_rotation
  model.set_meta("missing_model",packed==null and profile.kind!="melee")
  add_child(model)
  models[profile.id] = model
 actor.weapon.equipped.connect(update_model)
 var muzzle := Marker3D.new()
 muzzle.name = "Muzzle"
 add_child(muzzle)
 actor.weapon_muzzle = muzzle
 update_model(actor.weapon.profile)
func update_model(profile: WeaponProfile) -> void:
 for id in models: models[id].visible = id==profile.id
 if is_instance_valid(actor.weapon_muzzle): actor.weapon_muzzle.position.x = 0.48 if profile.two_handed else 0.20
func _process(_dt: float) -> void:
 visible = actor.health.health>0 and actor.control_enabled and actor.weapon.profile.kind!="melee"
