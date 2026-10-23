class_name GameplayHud
extends Control
## Logical canvas coordinates stay independent of the 3D render-buffer scale.
var arena: Node3D
var diagnostics := false
var controls_visible := false
var flash_left := 0.0
var tracer_from := Vector3.ZERO
var tracer_to := Vector3.ZERO
var hit_flash := false
var settings := PanelContainer.new()
var summary: Label
var render_slider := HSlider.new()
var ui_slider := HSlider.new()
var adaptive_toggle := CheckButton.new()
var settings_sync := false
var icons := {}
var layout := {}
const INK := Color("f4f1ed")
const AQUA := Color("70d5ed")
const PINK := Color("e989b4")
const BACK := Color(0.025,0.035,0.065,0.85)
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for key in ["crosshair","compass_north","player_marker","weapon_icon","radar_disc"]: icons[key] = arena.placeholder_assets.texture(key)
 build_settings()
func build_settings() -> void:
 add_child(settings)
 settings.add_theme_stylebox_override("panel",modal_style())
 settings.visible = false
 var scroll := ScrollContainer.new()
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 settings.add_child(scroll)
 var margin := MarginContainer.new()
 margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 for edge in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_"+edge,18)
 scroll.add_child(margin)
 var box := VBoxContainer.new()
 box.add_theme_constant_override("separation",12)
 margin.add_child(box)
 for label_text in ["DISPLAY",""]:
  var label := Label.new()
  label.text = label_text
  label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  box.add_child(label)
  if label_text.is_empty(): summary = label
 for pair in [["3D render scale",render_slider,0.5,1.0],["Interface scale",ui_slider,0.75,1.5]]:
  var label := Label.new()
  label.text = pair[0]
  box.add_child(label)
  var slider: HSlider = pair[1]
  slider.min_value = pair[2]; slider.max_value = pair[3]; slider.step = 0.05
  box.add_child(slider)
 adaptive_toggle.text = "Adaptive 3D resolution / 60 FPS target"
 box.add_child(adaptive_toggle)
 var note := Label.new()
 note.text = "3D quality changes independently of the HUD. Adaptive mode responds to sustained frame time."
 note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 box.add_child(note)
 var resolutions := OptionButton.new()
 for value in ["Window size…","960 × 540","1280 × 720","1440 × 900","1920 × 1080","2560 × 1440"]: resolutions.add_item(value)
 resolutions.item_selected.connect(func(index: int):
  if index>0:
   get_tree().root.mode = Window.MODE_WINDOWED
   get_tree().root.size = [Vector2i(960,540),Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(2560,1440)][index-1])
 box.add_child(resolutions)
 var fullscreen := CheckButton.new()
 fullscreen.text = "Fullscreen"
 fullscreen.button_pressed = get_tree().root.mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN]
 fullscreen.toggled.connect(func(value: bool): get_tree().root.mode = Window.MODE_FULLSCREEN if value else Window.MODE_WINDOWED)
 box.add_child(fullscreen)
 var close := Button.new()
 close.text = "Resume / F2"
 close.pressed.connect(toggle_settings)
 box.add_child(close)
 render_slider.value_changed.connect(func(value: float):
  if not settings_sync: arena.display_controller.set_render_scale(value))
 ui_slider.value_changed.connect(func(value: float):
  if not settings_sync: arena.display_controller.set_ui_scale(value))
 adaptive_toggle.toggled.connect(func(value: bool):
  if not settings_sync: arena.display_controller.set_adaptive(value))
 arena.display_controller.settings_changed.connect(sync_settings)
 sync_settings()
func sync_settings() -> void:
 settings_sync = true
 var display: DisplayController = arena.display_controller
 render_slider.value = display.current_scale
 render_slider.editable = not display.profile.adaptive
 ui_slider.value = display.profile.ui_scale
 adaptive_toggle.button_pressed = display.profile.adaptive
 settings_sync = false
func toggle_settings() -> void:
 settings.visible = not settings.visible
 if settings.visible:
  controls_visible = false
  if is_instance_valid(arena.animation_browser) and arena.animation_browser.visible: arena.animation_browser.toggle()
  Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
 elif DisplayServer.get_name()!="headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func on_shot(origin: Vector3, end: Vector3, hit: bool) -> void:
 tracer_from = origin; tracer_to = end; flash_left = 0.08; hit_flash = hit
func _process(dt: float) -> void:
 if not is_instance_valid(arena): return
 flash_left = maxf(0,flash_left-dt)
 var screen := get_viewport_rect().size
 layout = DisplayController.hud_layout(screen)
 if settings.visible:
  settings.size = Vector2(minf(480,screen.x-36),minf(620,screen.y-36))
  settings.position = (screen-settings.size)*0.5
  var display: DisplayController = arena.display_controller
  summary.text = "%d × %d  /  3D %d%%  /  UI %d%%"%[get_tree().root.size.x,get_tree().root.size.y,display.current_scale*100,display.profile.ui_scale*100]
 queue_redraw()
func text_at(text: String, at: Vector2, pixels := 18, color := INK, width := -1.0) -> void:
 draw_string(ThemeDB.fallback_font,at+Vector2(1,2),text,HORIZONTAL_ALIGNMENT_LEFT,width,pixels,Color(0,0,0,0.9))
 draw_string(ThemeDB.fallback_font,at,text,HORIZONTAL_ALIGNMENT_LEFT,width,pixels,color)
static func modal_style() -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color = Color("14212e")
 style.corner_radius_top_left = 8
 style.corner_radius_top_right = 8
 style.corner_radius_bottom_left = 8
 style.corner_radius_bottom_right = 8
 return style
func _draw() -> void:
 if not is_instance_valid(arena) or layout.is_empty(): return
 var screen := get_viewport_rect().size
 if settings.visible:
  draw_rect(Rect2(Vector2.ZERO,screen),Color(0,0,0,0.55))
  return
 if is_instance_valid(arena.animation_browser) and arena.animation_browser.visible: return
 var status: Rect2 = layout.status
 var ammo: Rect2 = layout.ammo
 var context: Rect2 = layout.context
 draw_rect(status,BACK); draw_rect(ammo,BACK)
 text_at("HARBOR",context.position+Vector2(0,22),24,PINK,context.size.x)
 text_at("F1 Controls / F2 Display",context.position+Vector2(0,47),14,INK,context.size.x)
 text_at("F3 Debug / F4 Animations",context.position+Vector2(0,67),14,AQUA,context.size.x)
 var health: float = arena.actor.health.health
 text_at("HEALTH",status.position+Vector2(16,24),14,PINK)
 text_at("%03d"%health,status.position+Vector2(status.size.x-68,28),24,PINK)
 draw_rect(Rect2(status.position+Vector2(16,40),Vector2(status.size.x-32,7)),Color("3b354b"))
 draw_rect(Rect2(status.position+Vector2(16,40),Vector2((status.size.x-32)*clampf(health/maxf(1,arena.actor.health.max_health),0,1),7)),PINK)
 var driving: bool = arena.transition.state=="driving"
 var seated: bool = arena.transition.state in ["driving","passenger","shuffling"]
 var car: DriveVehicle = arena.transition.vehicle if is_instance_valid(arena.transition.vehicle) else arena.vehicle
 var state: String = arena.actor.actions.life if arena.actor.actions.life!="alive" else arena.transition.state
 if state=="on_foot" and arena.actor.phase=="falling":state="falling"
 elif state=="on_foot" and arena.actor.phase=="landing" and arena.actor.fall.hard_landing:state="hard_landing"
 text_at(state.to_upper().replace("_"," "),status.position+Vector2(16,76),16,AQUA,status.size.x-32)
 text_at("%03d km/h"%absf(car.speed*3.6) if driving else "TEST YARD",status.position+Vector2(16,99),16,INK)
 var weapon: WeaponController = arena.weapon
 text_at("%d/%d"%[weapon.active_slot+1,weapon.inventory.size()],ammo.position+Vector2(14,28),14,PINK)
 text_at(weapon.profile.display_name,ammo.position+Vector2(58,26),14,AQUA,ammo.size.x-70)
 text_at("MELEE" if weapon.profile.kind=="melee" else "%02d / %03d"%[weapon.magazine,weapon.reserve],ammo.position+Vector2(58,61),26,INK,ammo.size.x-70)
 if weapon.reload_left>0: draw_rect(Rect2(ammo.position+Vector2(16,77),Vector2((ammo.size.x-32)*(1.0-weapon.reload_left/maxf(0.001,weapon.profile.reload_seconds)),4)),PINK)
 draw_radar(layout.radar)
 var message: String = "[Backspace] Respawn" if health<=0 else arena.transition.message
 var nearest: DriveVehicle = arena.nearest_vehicle()
 if message.is_empty() and arena.transition.state=="on_foot" and arena.actor.control_enabled and nearest!=null and arena.actor.global_position.distance_to(nearest.global_position)<arena.transition.profile.reach: message = "[E] Enter vehicle"
 if message.is_empty() and arena.transition.state=="passenger": message = "[X] Move to driver / [E] Exit"
 if message.is_empty() and arena.actor.stance.crouched and arena.transition.state=="on_foot": message = "CROUCHED / [C] Stand"
 if message.is_empty() and arena.transition.state=="approaching": message="Walking to vehicle / [E] Cancel"
 if message.is_empty() and arena.transition.state=="shuffling": message = "Moving to driver seat…"
 if message.is_empty() and arena.transition.state=="entering": message = "Entering vehicle…"
 elif message.is_empty() and arena.transition.state=="exiting": message = "Leaving vehicle…"
 if not message.is_empty():
  var width := minf(420,screen.x-36)
  text_at(message,Vector2((screen.x-width)*0.5,screen.y-196 if screen.x<1000 else screen.y-54),17,AQUA,width)
 if health>0 and weapon.profile.kind!="melee" and arena.actor.can_use_weapon() and arena.actor.actions.aim_weight>0.05 and arena.transition.state=="on_foot":
  var center: Vector2 = layout.center
  if icons.crosshair!=null: draw_texture_rect(icons.crosshair,Rect2(center-Vector2.ONE*23,Vector2.ONE*46),false)
  else:
   for axis in [Vector2.RIGHT,Vector2.DOWN]:
    draw_line(center-axis*10,center-axis*4,INK,2); draw_line(center+axis*4,center+axis*10,INK,2)
  if hit_flash and flash_left>0:
   for sign in [-1,1]: draw_line(center+Vector2(-8,8*sign),center+Vector2(8,-8*sign),PINK,2)
 draw_world_markers()
 if controls_visible or diagnostics: draw_help(screen)
func draw_radar(rect: Rect2) -> void:
 var center := rect.get_center()
 draw_circle(center,rect.size.x*0.5,BACK)
 if icons.radar_disc!=null: draw_texture_rect(icons.radar_disc,rect,false)
 draw_arc(center,rect.size.x*0.5-2,0,TAU,64,AQUA,2)
 # Local test-yard radar; it does not pretend to be the original game's map.
 var active: DriveVehicle = arena.transition.vehicle
 var origin: Vector3 = active.global_position if is_instance_valid(active) else arena.actor.global_position
 for target in arena.targets: radar_point(target.global_position,origin,center,PINK,3)
 for ped in arena.pedestrians: radar_point(ped.global_position,origin,center,INK,2)
 for child in arena.get_children():
  if child is DriveVehicle: radar_point(child.global_position,origin,center,AQUA,4)
 draw_line(center+Vector2(-50,0),center+Vector2(50,0),Color(1,1,1,0.1))
 draw_line(center+Vector2(0,-50),center+Vector2(0,50),Color(1,1,1,0.1))
 if icons.player_marker!=null: draw_texture_rect(icons.player_marker,Rect2(center-Vector2.ONE*8,Vector2.ONE*16),false)
 else: draw_circle(center,4,INK)
 var north := center+Vector2(0,-57).rotated(-arena.rig.yaw)
 if icons.compass_north!=null: draw_texture_rect(icons.compass_north,Rect2(north-Vector2.ONE*8,Vector2.ONE*16),false)
func radar_point(at: Vector3, origin: Vector3, center: Vector2, color: Color, radius: float) -> void:
 var delta := Vector2(at.x-origin.x,at.z-origin.z).rotated(-arena.rig.yaw)*1.6
 if delta.length()<59: draw_circle(center+delta,radius,color)
func draw_world_markers() -> void:
 var camera: Camera3D = arena.rig.camera
 if flash_left>0 and not camera.is_position_behind(tracer_from) and not camera.is_position_behind(tracer_to): draw_line(camera.unproject_position(tracer_from),camera.unproject_position(tracer_to),Color(1,0.84,0.48,flash_left/0.08),2)
 if diagnostics:
  for wheel in arena.vehicle.wheels:
   if not camera.is_position_behind(wheel.point): draw_circle(camera.unproject_position(wheel.point),4,AQUA if wheel.touching else PINK)
func draw_help(screen: Vector2) -> void:
 var rect := Rect2(Vector2(18,116),Vector2(minf(430,screen.x-36),maxf(180,minf(370,screen.y-134))))
 draw_rect(rect,BACK)
 var lines: Array[String] = ["CONTROLS","WASD Move / steer","Shift Sprint (tap boost) / Alt Walk","Space Jump / vehicle brake","RMB Aim / LMB Fire or strike","R Reload / E Enter, exit or bail", "C Crouch / V Camera / X Change seat", "Alt + E Passenger entry", "F6 Repair nearby stopped vehicle (lab)","Wheel / Q / Z / 1–9 Switch weapon","Backspace Respawn after death / Esc Cursor"]
 if diagnostics:
  var motor: CharacterMotor = arena.actor
  lines = ["GAMEPLAY / PHYSICS","%s / grounded %s"%[motor.phase,motor.grounded],"Velocity %.2f %.2f %.2f m/s"%[motor.velocity.x,motor.velocity.y,motor.velocity.z],"Fall %.1f m / impact %.1f m/s / damage %.1f"%[motor.fall.drop,motor.fall.last_impact_speed,motor.fall.last_damage],"Steering %.2f / camera %.2f"%[arena.vehicle.steering,arena.rig.obstruction_fraction],"Gameplay %.0f us / tick %d"%[arena.last_tick_us,arena.tick_number],"3D %.0f%% / sampled %.1f ms"%[arena.display_controller.current_scale*100,arena.display_controller.last_frame_ms],"Collision: Debug > Visible Collision Shapes"]
 var step := minf(28,(rect.size.y-20)/lines.size())
 for i in range(lines.size()):
  text_at(lines[i],rect.position+Vector2(16,18+i*step),16 if i==0 else (12 if step<22 else 14),AQUA if i==0 else INK,rect.size.x-32)

