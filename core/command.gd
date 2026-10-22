class_name GameplayCommand
extends RefCounted
## One physics-tick intent. Replace the producer for AI/replay/network input.
var move := Vector2.ZERO
var jump := false
var aim := false
var fire := false
var reload := false
var interact := false
var sprint := false
var walk := false
var brake := false
var look := Vector2.ZERO
