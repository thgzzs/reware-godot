class_name CorpseHitbox
extends Area3D
## Query-only melee target. A settled corpse never pushes cars or receives forces.
var actor:CharacterMotor
var active:=false
func configure(owner_actor:CharacterMotor) -> void:
 actor=owner_actor;collision_layer=0;collision_mask=0;monitoring=false;monitorable=true;top_level=true
 var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=0.28;capsule.height=1.65;shape.shape=capsule;shape.rotation.x=PI/2;add_child(shape)
func activate(at:Vector3,orientation:Basis) -> void:
 active=true;global_transform=Transform3D(orientation,at);collision_layer=32
func clear() -> void:active=false;collision_layer=0
func receive_hit(event:DamageEvent) -> void:actor.receive_hit(event)
