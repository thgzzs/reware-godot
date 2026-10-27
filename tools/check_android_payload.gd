extends SceneTree
## Run against a clean extraction of APK assets to verify the shipped build.
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not ImportedAssetSetup.available():
  push_error("APK native animation/database resources are unavailable")
  quit(1);return
 var arena=load("res://scenes/arena.tscn").instantiate()
 arena.test_mode=true;arena.force_touch_controls=true;root.add_child(arena)
 for i in range(90):await physics_frame;await process_frame
 var vehicles:=0
 for child in arena.get_children():
  if child is DriveVehicle:vehicles+=1
 var build_ok:bool=ProjectSettings.get_setting("application/config/build_number",0)==13 and ProjectSettings.get_setting("application/config/version","")=="0.8.2-controller13" and arena.overlay.build_label=="GAMEPLAY REVISION / BUILD 13"
 var native_ok:bool=arena.actor.reference_enabled and arena.actor.reference_motion.library.get_animation_list().size()==1168 and arena.weapon.inventory.size()==24 and arena.pedestrians.size()==4 and vehicles==7 and arena.mobile_controls.enabled and arena.vehicle.seating.definitions.size()==2 and is_equal_approx(arena.actor.reference_motion.library.get_animation("WEAPON_crouch").length,0.5)
 var bike:DriveVehicle=arena.get_node_or_null("pcj600")
 var fixes_ok:bool=arena.actor.reaction_body.recovery is PedRecoverySolver and arena.actor.profile.jump_buffer>=0.1 and arena.weapon.equip_action is WeaponEquipState and bike!=null and bike.bike.profile.reverse_speed>=2.0
 var classic:MovementProfile=load("res://tuning/movement_classic.tres")
 var controller_ok:bool=classic!=null and classic.classic_revc and classic.jump_buffer==0 and not arena.actor.profile.classic_revc and InputMap.has_action("look_left") and GameplayCommand.new().look_stick==Vector2.ZERO
 var label_width:=ThemeDB.fallback_font.get_string_size(arena.overlay.build_label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
 var layout_ok:bool=label_width<=DisplayController.hud_layout(Vector2(480,720)).context.size.x
 var holds:=0
 var sprints:=0
 arena.actor.respawn(Vector3(-44,0.94,44))
 for slot in range(arena.weapon.inventory.size()):
  if arena.weapon.inventory[slot].profile.id not in ["m4","ruger","shotgun","stubbyshotgun","spas12shotgun","m60"]:continue
  arena.weapon.equip_slot(slot)
  for i in range(40):await physics_frame;await process_frame
  if arena.actor.actions.standing_hold_clip=="IDLE_armed" and not arena.actor.actions.standing_hold_native_ready and arena.actor.actions.standing_hold_weight>0.99 and arena.actor.actions.aim_weight==0:holds+=1
  var sprint:=GameplayCommand.new();sprint.move=Vector2(0,-1);sprint.sprint=true;arena.injected_command=sprint
  for i in range(75):await physics_frame;await process_frame
  var pose:SkinnedMotionVisual=arena.actor.reference_pose
  var thigh:=pose.skeleton.find_bone("R Thigh")
  var before:=pose.skeleton.get_bone_pose_rotation(thigh)
  for i in range(10):await physics_frame;await process_frame
  if arena.actor.actions.standing_hold_clip=="IDLE_armed" and arena.actor.actions.standing_hold_weight>0.99 and arena.actor.actions.upper_allowed and arena.actor.drive_velocity.length()>3 and before.angle_to(pose.skeleton.get_bone_pose_rotation(thigh))>0.15:sprints+=1
  arena.injected_command=GameplayCommand.new();arena.actor.respawn(Vector3(-44,0.94,44))
 var map_ok:bool=arena.traversal_course.void_platforms.size()==13 and arena.traversal_course.slopes.size()==6 and arena.traversal_course.drop_decks.size()==4 and arena.traversal_course.garden.size()==7
 var gap:=PhysicsRayQueryParameters3D.create(Vector3(12,5,90),Vector3(12,-25,90),1)
 map_ok=map_ok and arena.get_world_3d().direct_space_state.intersect_ray(gap).is_empty()
 print("APK BUILD 13 metadata=",build_ok," native=",native_ok," controller=",controller_ok," label_fits=",layout_ok," clips=",arena.actor.reference_motion.library.get_animation_list().size()," vehicles=",vehicles," standing_holds=",holds," sprint_holds=",sprints," expanded_map=",map_ok)
 var valid:bool=build_ok and native_ok and controller_ok and layout_ok and fixes_ok and holds==6 and sprints==6 and map_ok
 arena.queue_free();await process_frame;quit(0 if valid else 1)
