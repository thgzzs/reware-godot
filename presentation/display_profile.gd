class_name DisplayProfile
extends Resource
@export_range(0.5,1.0,0.05) var render_scale := 1.0
@export_range(0.75,1.5,0.05) var ui_scale := 1.0
@export var adaptive := false
@export_range(30,144,1) var target_fps := 60.0
@export_range(0.5,1.0,0.05) var minimum_scale := 0.5
@export var sample_window_seconds := 1.5
@export var adjustment_cooldown_seconds := 2.0
@export var safe_margin := 18.0
