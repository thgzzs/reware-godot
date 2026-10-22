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
func receive(amount: float) -> void:
 if health<=0: return
 var actual := amount*defense_multiplier
 health = maxf(0,health-actual)
 damaged.emit(actual)
 if health<=0: depleted.emit()

