extends SceneTree
## Run against a clean extraction of APK assets to verify the shipped build.
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var arena=load("res://scenes/arena.tscn").instantiate()
 arena.test_mode=true;arena.force_touch_controls=true;root.add_child(arena)
 for i in range(90):await physics_frame;await process_frame
 var vehicles:=0
 for child in arena.get_children():
  if child is DriveVehicle:vehicles+=1
 var build_ok:bool=ProjectSettings.get_setting("application/config/build_number",0)==9 and ProjectSettings.get_setting("application/config/version","")=="0.7.0-gameplay9" and arena.overlay.build_label=="GAMEPLAY REVISION / BUILD 9"
 var native_ok:bool=arena.actor.reference_enabled and arena.actor.reference_motion.library.get_animation_list().size()==1168 and arena.weapon.inventory.size()==24 and arena.pedestrians.size()==4 and vehicles==7 and arena.mobile_controls.enabled and arena.vehicle.seating.definitions.size()==2 and is_equal_approx(arena.actor.reference_motion.library.get_animation("WEAPON_crouch").length,0.5)
 var fixes_ok:bool=arena.actor.reaction_body.recovery is PedRecoverySolver and arena.actor.profile.jump_buffer>=0.1 and arena.weapon.equip_action is WeaponEquipState and arena.get_node("pcj600").bike.profile.reverse_speed>=2.0
 var label_width:=ThemeDB.fallback_font.get_string_size(arena.overlay.build_label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
 var layout_ok:bool=label_width<=DisplayController.hud_layout(Vector2(480,720)).context.size.x
 print("APK BUILD 9 metadata=",build_ok," native=",native_ok," label_fits=",layout_ok," clips=",arena.actor.reference_motion.library.get_animation_list().size()," vehicles=",vehicles)
 arena.queue_free();await process_frame;quit(0 if build_ok and native_ok and layout_ok and fixes_ok else 1)
