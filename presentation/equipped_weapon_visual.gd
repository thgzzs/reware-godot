class_name EquippedWeaponVisual
extends Node3D
## Replace each group scene independently; primitive long guns are explicit fallbacks.
var actor: CharacterMotor
var assets: PlaceholderAssets
var models := {}
func _ready() -> void:
	for group in ["colt45","rifle","shotgun"]:
		var packed := assets.scene(assets.weapon_scenes.get(group,assets.weapon_scene if group=="colt45" else ""))
		var model: Node3D
		if packed!=null: model = packed.instantiate()
		else:
			model = Node3D.new()
			var receiver := LabGeometry.box(model,Vector3(0.35,0.07,0.07),Vector3(0.02,0,0),Color("48515a"))
			receiver.name = "PlaceholderReceiver"
			LabGeometry.box(model,Vector3(0.30,0.035,0.035),Vector3(0.33,0,0),Color("272e35"))
			LabGeometry.box(model,Vector3(0.17,0.06,0.06),Vector3(-0.20,0,0),Color("825d43"))
		model.position = assets.weapon_offset
		model.rotation_degrees = assets.weapon_rotation
		add_child(model)
		models[group] = model
	actor.weapon.equipped.connect(update_model)
	actor.health.depleted.connect(hide)
	actor.health.restored.connect(show)
	update_model(actor.weapon.profile)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.20,0,0)
	add_child(muzzle)
	actor.weapon_muzzle = muzzle
func update_model(profile: WeaponProfile) -> void:
	var group := "colt45"
	if "shotgun" in profile.display_name.to_lower() or profile.pellets>1: group = "shotgun"
	elif profile.heavy or profile.animation_group in ["rifle","riflebad","m4","ruger"]: group = "rifle"
	for key in models: models[key].visible = key==group
	if is_instance_valid(actor.weapon_muzzle): actor.weapon_muzzle.position.x = 0.20 if group=="colt45" else 0.48
