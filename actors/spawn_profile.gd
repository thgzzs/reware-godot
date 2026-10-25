class_name ActorSpawnProfile
extends Resource
## Respawn policy is independent of locomotion, health and AI decisions.
@export var death_delay := 8.0
@export var void_height := -15.0
@export var retry_seconds := 0.5
@export var clearance_radius := 1.25
@export var clearance_rings := 3
@export var floor_height_tolerance := 0.6
