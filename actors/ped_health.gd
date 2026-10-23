class_name PedHealth
extends Node
signal damaged(amount: float)
signal depleted
signal restored
@export var max_health := 100.0
var health := 100.0
var defense_multiplier := 1.0
func reset() -> void:
 health = max_health
 restored.emit()
func receive(amount: float, use_combat_defense := true) -> void:
 if health<=0: return
 var actual := maxf(0,amount)*(defense_multiplier if use_combat_defense else 1.0)
 health = maxf(0,health-actual)
 damaged.emit(actual)
 if health<=0: depleted.emit()

