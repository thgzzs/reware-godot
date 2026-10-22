class_name PedHealth
extends Node
signal damaged(amount: float)
signal depleted
var health := 100.0
var defense_multiplier := 1.0
func receive(amount: float) -> void:
 if health<=0: return
 var actual := amount*defense_multiplier
 health = maxf(0,health-actual)
 damaged.emit(actual)
 if health<=0: depleted.emit()
