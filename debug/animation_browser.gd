class_name ImportedAnimationBrowser
extends PanelContainer
var actor: CharacterMotor
var database: ImportedGameplayDatabase
var fight_note := ""
var picker := ItemList.new()
var search := LineEdit.new()
var status := Label.new()
var slider := HSlider.new()
var names: PackedStringArray
var updating := false
func _ready() -> void:
 custom_minimum_size = Vector2(280,320)
 var style := GameplayHud.modal_style()
 style.content_margin_left = 12
 style.content_margin_right = 12
 style.content_margin_top = 12
 style.content_margin_bottom = 12
 add_theme_stylebox_override("panel",style)
 var layout := VBoxContainer.new()
 add_child(layout)
 var heading := Label.new()
 heading.text = "ANIMATIONS / %d ENTRIES"%actor.reference_motion.library.get_animation_list().size()
 layout.add_child(heading)
 var note := Label.new()
 note.text = "Search, play or scrub a clip.\nClose to resume locomotion."
 note.add_theme_font_size_override("font_size",12)
 layout.add_child(note)
 search.placeholder_text = "Filter clips (walk, car, fight...)"
 layout.add_child(search)
 search.text_changed.connect(refilter)
 picker.custom_minimum_size = Vector2(0,120)
 picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
 layout.add_child(picker)
 picker.item_selected.connect(select)
 slider.min_value = 0
 slider.max_value = 1
 slider.step = 0.001
 layout.add_child(slider)
 slider.value_changed.connect(func(value: float):
  if not updating:
   actor.reference_motion.preview_time = value
   actor.reference_motion.preview_playing = false)
 layout.add_child(status)
 var buttons := HBoxContainer.new()
 layout.add_child(buttons)
 var play := Button.new()
 play.text = "Play / pause"
 play.pressed.connect(func(): actor.reference_motion.preview_playing = not actor.reference_motion.preview_playing)
 buttons.add_child(play)
 var close := Button.new()
 close.text = "Resume gameplay / F4"
 close.pressed.connect(toggle)
 buttons.add_child(close)
 names = actor.reference_motion.library.get_animation_list()
 names.sort()
 refilter("")
 visible = false
func refilter(filter_text: String) -> void:
 picker.clear()
 for name in names:
  if filter_text.to_lower() in name.to_lower(): picker.add_item(name)
func select(index: int) -> void:
 var name := picker.get_item_text(index)
 actor.reference_motion.preview_clip = name
 actor.reference_motion.preview_time = 0
 actor.reference_motion.preview_playing = true
 slider.max_value = actor.reference_motion.duration(name)
 fight_note = ""
 if database!=null:
  for move in database.fight_moves:
   if move.get("animation_clip","")==name:
    if move.has_strike_window:
     fight_note += "\n%s: %.3f–%.3f s / source damage %d"%[move.name,move.start_seconds,move.end_seconds,move.damage_source]
func toggle() -> void:
 visible = not visible
 if visible:
  if picker.item_count>0:
   picker.select(0)
   select(0)
  Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
 else:
  actor.reference_motion.preview_clip = ""
  actor.reference_motion.phase = "idle"
  actor.reference_motion.was_sprinting = false
  actor.drive_velocity = Vector3.ZERO
  actor.velocity = Vector3.ZERO
  if DisplayServer.get_name()!="headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func _process(_dt: float) -> void:
 if not visible: return
 var screen := get_viewport_rect().size
 size = Vector2(minf(460,screen.x-36),minf(650,screen.y-36))
 position = Vector2(screen.x-size.x-18,18)
 var motion := actor.reference_motion
 status.text = "%s  %.3f / %.3f s"%[motion.preview_clip,motion.preview_time,motion.duration(motion.preview_clip)]+fight_note
 updating = true
 slider.value = motion.preview_time
 updating = false
