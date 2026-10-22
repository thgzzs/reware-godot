class_name DisplayController
extends Node
signal settings_changed
var profile: DisplayProfile
var current_scale := 1.0
var sample_seconds := 0.0
var sample_frames := 0
var cooldown := 0.0
var last_frame_ms := 0.0
var window: Window
var persist_settings := true
var scale_telemetry := GameplayTelemetry.new()
func _ready() -> void:
 window = get_tree().root
 profile = preload("res://tuning/display.tres").duplicate()
 var config := ConfigFile.new()
 if persist_settings and config.load("user://display.cfg")==OK:
  profile.render_scale = clampf(float(config.get_value("display","render_scale",1.0)),0.5,1.0)
  profile.ui_scale = clampf(float(config.get_value("display","ui_scale",1.0)),0.75,1.5)
  profile.adaptive = bool(config.get_value("display","adaptive",false))
 window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
 window.content_scale_size = Vector2i(720,720)
 window.min_size = Vector2i(480,360)
 window.content_scale_factor = profile.ui_scale
 window.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
 set_render_scale(profile.render_scale,false)
func save_settings() -> void:
 if not persist_settings: return
 var config := ConfigFile.new()
 config.set_value("display","render_scale",profile.render_scale)
 config.set_value("display","ui_scale",profile.ui_scale)
 config.set_value("display","adaptive",profile.adaptive)
 config.save("user://display.cfg")
func set_render_scale(value: float, persist := true) -> void:
 current_scale = snappedf(clampf(value,profile.minimum_scale,1.0),0.05)
 if not profile.adaptive: profile.render_scale = current_scale
 window.scaling_3d_scale = current_scale
 if persist: save_settings()
 settings_changed.emit()
func set_ui_scale(value: float) -> void:
 profile.ui_scale = clampf(value,0.75,1.5)
 window.content_scale_factor = profile.ui_scale
 save_settings()
 settings_changed.emit()
func set_adaptive(value: bool) -> void:
 profile.adaptive = value
 sample_seconds = 0
 sample_frames = 0
 cooldown = 0
 if not value: set_render_scale(profile.render_scale,false)
 save_settings()
 settings_changed.emit()
func sample_frame(seconds: float) -> void:
 # Sustained frame-time signal, not a GPU-time or performance-parity claim.
 # Ignore stalls/focus loss and use hysteresis/cooldown to avoid oscillation.
 if not profile.adaptive or seconds<=0 or seconds>0.15: return
 cooldown = maxf(0,cooldown-seconds)
 sample_seconds += seconds
 sample_frames += 1
 if sample_seconds<profile.sample_window_seconds: return
 last_frame_ms = sample_seconds*1000.0/sample_frames
 var target_ms := 1000.0/profile.target_fps
 var next := current_scale
 if cooldown<=0:
  if last_frame_ms>target_ms*1.12: next -= 0.05
  elif last_frame_ms<target_ms*0.85: next += 0.05
 if not is_equal_approx(next,current_scale):
  var before := Time.get_ticks_usec()
  set_render_scale(next,false)
  scale_telemetry.record(Time.get_ticks_usec()-before)
  cooldown = profile.adjustment_cooldown_seconds
 sample_seconds = 0
 sample_frames = 0
func _process(dt: float) -> void:
 if DisplayServer.get_name()=="headless" or not window.has_focus(): return
 sample_frame(dt)
static func hud_layout(size: Vector2, margin: float = 18.0) -> Dictionary:
 var compact := size.x<900 or size.y<600
 var card_width := minf(290,size.x*0.43)
 var bottom_height := 92.0
 return {"compact":compact,
  "status":Rect2(Vector2(size.x-card_width-margin,margin),Vector2(card_width,112)),
  "context":Rect2(Vector2(margin,margin),Vector2(minf(330,size.x-card_width-margin*3),84)),
  "ammo":Rect2(Vector2(size.x-card_width-margin,size.y-bottom_height-margin),Vector2(card_width,bottom_height)),
  "radar":Rect2(Vector2(margin,size.y-150-margin),Vector2(150,150)),
  "center":size*0.5,
  "modal":Rect2(Vector2(margin,margin),size-Vector2.ONE*margin*2)}
