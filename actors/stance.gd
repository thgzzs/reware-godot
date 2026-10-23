class_name CharacterStance
extends RefCounted
var profile: StanceProfile = preload("res://tuning/stance.tres")
var actor: CharacterMotor
var crouched := false
var shape := CapsuleShape3D.new()
var query := PhysicsShapeQueryParameters3D.new()
func configure(owner_actor: CharacterMotor) -> void:
 actor = owner_actor
 shape.radius = (actor.normal_shape as CapsuleShape3D).radius
 shape.height = profile.crouch_height
 query.shape = actor.normal_shape
 query.collision_mask = 15
 query.exclude = [actor.get_rid()]
 query.margin = 0.001
func can_stand() -> bool:
 query.transform = actor.global_transform.translated(Vector3.UP*0.02)
 return actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func set_crouched(value: bool, force := false) -> bool:
 if value==crouched: return true
 if not value and not force and not can_stand(): return false
 crouched = value
 var collider := actor.get_node("CollisionShape3D") as CollisionShape3D
 collider.shape = shape if crouched else actor.normal_shape
 collider.position.y = -(float((actor.normal_shape as CapsuleShape3D).height)-shape.height)*0.5 if crouched else 0
 actor.actions.crouched = crouched
 return true
func read_command(cmd: GameplayCommand) -> void:
 if not actor.control_enabled: return
 if cmd.crouch and actor.grounded and actor.phase=="grounded": set_crouched(not crouched)
 if crouched and (cmd.sprint or cmd.jump): set_crouched(false)
func reset() -> void:
 crouched = false
 actor.actions.crouched = false
