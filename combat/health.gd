class_name DamageReceiver
extends StaticBody3D
signal damaged(amount: float, remaining: float)
signal depleted
@export var max_health := 100.0
var health := 100.0
var reset_left := 0.0
@onready var model: MeshInstance3D = $Mesh
func _ready() -> void:
 health = max_health
func receive_damage(amount: float, _point: Vector3, _direction: Vector3) -> void:
 if health <= 0: return
 health = maxf(0,health-amount)
 damaged.emit(amount,health)
 if health <= 0:
  depleted.emit()
  model.visible = false
  set_deferred("collision_layer",0)
  reset_left = 3.0
func _physics_process(dt: float) -> void:
 if reset_left <= 0: return
 reset_left -= dt
 if reset_left <= 0:
  health = max_health
  model.visible = true
  collision_layer = 8
