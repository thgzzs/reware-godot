class_name LabOverlay
extends Control
var arena: Node3D
var diagnostics := false
var flash_left := 0.0
var tracer_from := Vector3.ZERO
var tracer_to := Vector3.ZERO
var hit_flash := false
var title: Label
var subtitle: Label
var state_label: Label
var hint: Label
var metrics: Label
func label_at(text: String, at: Vector2, size: int, color: Color) -> Label:
 var label := Label.new()
 label.text = text
 label.position = at
 label.add_theme_font_size_override("font_size",size)
 label.add_theme_color_override("font_color",color)
 add_child(label)
 return label
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 title = label_at("H A R B O R",Vector2(34,25),28,Color("e4f6f0"))
 subtitle = label_at("BEHAVIOR LAB   /   FIRST PLAYABLE",Vector2(35,65),12,Color("91b5bc"))
 state_label = label_at("",Vector2(35,120),21,Color("75e0c6"))
 hint = label_at("",Vector2(35,160),15,Color("d7e5e5"))
 metrics = label_at("",Vector2(35,270),14,Color("c0d4db"))
func on_shot(origin: Vector3, end: Vector3, hit: bool) -> void:
 tracer_from = origin
 tracer_to = end
 flash_left = 0.08
 hit_flash = hit
func _process(dt: float) -> void:
 if not is_instance_valid(arena): return
 flash_left = maxf(0,flash_left-dt)
 var driving: bool = arena.transition.state == "driving"
 state_label.text = arena.transition.state.to_upper().replace("_"," ")
 if driving:
  hint.text = "W / S  Accelerate & reverse
A / D  Steer    SPACE  Brake
E  Exit when stopped"
 else:
  hint.text = "W A S D  Move    SHIFT  Sprint
SPACE  Jump    RMB  Aim    LMB  Fire
R  Reload    E  Enter vehicle"
 hint.text += "
F3  Diagnostics    ESC  Release mouse"
 var nearest: DriveVehicle = arena.nearest_vehicle()
 if not driving and nearest != null and arena.actor.global_position.distance_to(nearest.global_position)<arena.transition.profile.reach:
  hint.text += "

[E]  Enter LAB coupe"
 if not arena.transition.message.is_empty(): hint.text += "
"+arena.transition.message
 metrics.visible = diagnostics
 if diagnostics:
  var motor: CharacterMotor = arena.actor
  var car: DriveVehicle = arena.vehicle
  var loads := ""
  for wheel in car.wheels: loads += "%4.0f  " % wheel.normal_load
  metrics.text = "MOTOR  %s / grounded %s
velocity  %.2f  %.2f  %.2f m/s
step %.3f m / impact %.2f m/s
VEHICLE  %.1f km/h / steer %.2f rad
wheel loads [N]  %s
CAMERA  sweep %.3f
GAMEPLAY  last %.0f us / tick %d
Physics shapes: Debug > Visible Collision Shapes" % [motor.phase,motor.grounded,motor.velocity.x,motor.velocity.y,motor.velocity.z,motor.last_step,motor.last_impact_speed,car.speed*3.6,car.steering,loads,arena.rig.obstruction_fraction,arena.last_tick_us,arena.telemetry.ticks]
 queue_redraw()
func _draw() -> void:
 if not is_instance_valid(arena): return
 var screen := get_viewport_rect().size
 draw_rect(Rect2(18,15,355,238),Color(0.025,0.06,0.08,0.84))
 draw_rect(Rect2(18,15,3,238),Color("75e0c6"))
 var center := screen*0.5
 var cross_color := Color("ffcb79") if hit_flash and flash_left>0 else Color("e7fff5")
 for axis in [Vector2.RIGHT,Vector2.DOWN]:
  draw_line(center+axis*5,center+axis*11,cross_color,2)
  draw_line(center-axis*5,center-axis*11,cross_color,2)
 var weapon: WeaponController = arena.weapon
 draw_rect(Rect2(screen.x-226,screen.y-114,204,90),Color(0.025,0.06,0.08,0.85))
 draw_string(ThemeDB.fallback_font,Vector2(screen.x-206,screen.y-80),weapon.profile.display_name,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("91b5bc"))
 draw_string(ThemeDB.fallback_font,Vector2(screen.x-206,screen.y-45),"%02d / %03d" % [weapon.magazine,weapon.reserve],HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("e7fff5"))
 if weapon.reload_left>0:
  draw_rect(Rect2(screen.x-206,screen.y-30,164*(1.0-weapon.reload_left/weapon.profile.reload_seconds),3),Color("ffcb79"))
 draw_string(ThemeDB.fallback_font,Vector2(35,screen.y-30),"01 / TRAVERSE     02 / TARGET RANGE     03 / DRIVE",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("c0d4db"))
 if flash_left>0:
  var camera: Camera3D = arena.rig.camera
  if not camera.is_position_behind(tracer_from) and not camera.is_position_behind(tracer_to):
   draw_line(camera.unproject_position(tracer_from),camera.unproject_position(tracer_to),Color(1,0.84,0.48,flash_left/0.08),2)
 if diagnostics:
  var camera: Camera3D = arena.rig.camera
  for wheel in arena.vehicle.wheels:
   if not camera.is_position_behind(wheel.point):
    draw_circle(camera.unproject_position(wheel.point),5,Color("75e0c6") if wheel.touching else Color("ff805c"))
