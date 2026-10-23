class_name OccupantHitbox
extends Area3D
var actor: CharacterMotor
func receive_hit(event: DamageEvent) -> void:
 if is_instance_valid(actor): actor.receive_hit(event)
