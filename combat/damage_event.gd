class_name DamageEvent
extends RefCounted
## One immutable-by-convention hit description across bullets, melee and impacts.
var amount := 0.0
var point := Vector3.ZERO
var direction := Vector3.ZERO
var normal := Vector3.ZERO
var kind := "bullet"
var part := "torso"
var source: Node
var relative_speed := 0.0
static func make(value: float, at: Vector3, toward: Vector3, type := "bullet", from: Node = null) -> DamageEvent:
 var event := DamageEvent.new()
 event.amount = maxf(0,value)
 event.point = at
 event.direction = toward.normalized()
 event.kind = type
 event.source = from
 return event
static func deliver(receiver: Object, event: DamageEvent) -> void:
 if not is_instance_valid(receiver): return
 if receiver.has_method("receive_hit"): receiver.receive_hit(event)
 elif receiver.has_method("receive_damage"): receiver.receive_damage(event.amount,event.point,event.direction)
