extends SceneTree
var arena: Node3D
var results: Array[Dictionary] = []
var failures := 0
var metrics := {}
func _initialize() -> void: run.call_deferred()
func frames(count: int, cmd: GameplayCommand = null) -> void:
 arena.injected_command = cmd if cmd!=null else GameplayCommand.new()
 for i in range(count):await physics_frame;await process_frame
func check(label: String, passed: bool, value: Variant = null) -> void:
 results.append({"name":label,"passed":passed,"measured":value})
 if not passed:failures+=1
 print("PASS " if passed else "FAIL ",label," ",value)
func run() -> void:
 arena=preload("res://scenes/arena.tscn").instantiate();arena.test_mode=true;root.add_child(arena)
 await frames(100)
 var actor: CharacterMotor=arena.actor
 var car: DriveVehicle=arena.vehicle
 var gun: WeaponController=arena.weapon
 check("exact engine and fixed Jolt timestep",Engine.get_version_info().string.begins_with("4.7.2") and ProjectSettings.get_setting("physics/3d/physics_engine")=="Jolt Physics" and Engine.physics_ticks_per_second==60)
 check("reference gravity uses normalized 50 Hz units",is_equal_approx(actor.profile.gravity,20.0) and is_equal_approx(float(ProjectSettings.get_setting("physics/3d/default_gravity")),20.0))
 check("jump impulse derives from 8.5/70 normalized momentum",absf(actor.profile.jump_speed-425.0/70.0)<0.0001,actor.profile.jump_speed)
 var props:=get_nodes_in_group("physical_props")
 check("trash cans are independent solid rigid bodies",props.size()==2 and props[0] is PhysicalProp and props[0].mass>1)
 var prop: PhysicalProp=props[0]
 var prop_before:=prop.global_position
 DamageEvent.deliver(prop,DamageEvent.make(25,prop.global_position+Vector3.UP*0.8,Vector3.RIGHT))
 await frames(30)
 check("bullet impulse translates and rotates a trash can",prop.global_position.distance_to(prop_before)>0.08 and prop.hits==1,{"distance":prop.global_position.distance_to(prop_before),"rotation":prop.rotation})
 var variants:Array[DriveVehicle]=[]
 for child in arena.get_children():
  if child is DriveVehicle and child.kind=="car":variants.append(child)
 check("independent RWD FWD AWD physics vehicles exist",variants.size()==3 and variants[0].profile.driven_rear and not variants[0].profile.driven_front and variants[1].profile.driven_front and not variants[1].profile.driven_rear and variants[2].profile.driven_front and variants[2].profile.driven_rear)
 check("vehicle masses and dimensions are distinct",variants[0].mass!=variants[1].mass and variants[1].mass!=variants[2].mass and (variants[1].get_node("Hull").shape as BoxShape3D).size!=(variants[2].get_node("Hull").shape as BoxShape3D).size)
 check("native two-door car retains four marker-defined seats",car.seating.definitions.size()==4 and car.doors.size()==2)
 check("four-door native car keeps four hinges and rear-door seat mappings",variants[2].doors.size()==4 and variants[2].seating.definitions[3].door==3)
 var unarmed:=-1
 for i in range(gun.inventory.size()):
  if gun.inventory[i].profile.id=="unarmed":unarmed=i
 check("native inventory exposes exact available models and unarmed",unarmed>=0 and gun.inventory[0].profile.id=="colt45" and gun.inventory[0].profile.source_model_id>0)
 var fake_alias:=false
 for item in gun.inventory:
  var p:WeaponProfile=item.profile
  if p.id!="unarmed" and not p.model_scene.ends_with("/"+p.id+".scn"):fake_alias=true
 check("weapons never substitute another firearm's mesh",not fake_alias)
 var camera_modes:=[]
 for i in range(3):
  var cycle:=GameplayCommand.new();cycle.camera_cycle=true;await frames(1,cycle);await frames(30)
  camera_modes.append(arena.rig.foot_mode)
 check("on-foot camera cycles near medium far with finite framing",camera_modes==[2,0,1] and arena.rig.camera.global_position.is_finite(),camera_modes)
 actor.respawn(Vector3(-28,0.94,38));await frames(30)
 gun.equip_slot(0);gun.magazine=gun.profile.magazine_size
 var fire:=GameplayCommand.new();fire.fire=true;fire.aim=true
 var jump:=GameplayCommand.new();jump.jump=true;jump.fire=true;jump.aim=true
 var shots:=gun.shots
 await frames(1,jump)
 for i in range(20):await frames(1,fire)
 check("launch and airborne firing never spend ammunition",gun.shots==shots and gun.magazine==gun.profile.magazine_size,{"phase":actor.phase,"shots":gun.shots-shots})
 await frames(70)
 await frames(20,fire)
 check("grounded weapon control resumes after landing",gun.shots>shots)
 var crouch:=GameplayCommand.new();crouch.crouch=true
 await frames(1,crouch);await frames(15)
 check("crouch preserves feet with a shorter collider",actor.stance.crouched and (actor.get_node("CollisionShape3D").shape as CapsuleShape3D).height<1.3 and actor.grounded)
 var origin:=actor.global_position
 var move:=GameplayCommand.new();move.move=Vector2(0,-1)
 await frames(20,move)
 check("source crouch holds position instead of generic crouch running",actor.global_position.distance_to(origin)<0.04,actor.global_position.distance_to(origin))
 gun.reload_left=0;gun.magazine=gun.profile.magazine_size;gun.cooldown=0
 shots=gun.shots
 await frames(15,fire)
 check("crouch shooting works without leaving crouch",actor.stance.crouched and gun.shots>shots)
 var roof:=LabGeometry.box(arena,Vector3(3,0.2,3),actor.global_position+Vector3(0,0.55,0),Color.GRAY,true)
 await frames(2);await frames(1,crouch)
 check("blocked standing volume keeps crouch collision",actor.stance.crouched)
 roof.queue_free();await frames(3);await frames(1,crouch);await frames(5)
 check("standing restores after headroom clears",not actor.stance.crouched and actor.grounded)
 var visual:SkinnedMotionVisual=actor.reference_pose
 var left:=visual.skeleton.find_bone("L UpperArm")
 arena.set_physics_process(false)
 actor.reference_motion.phase="idle";actor.reference_motion.set_clip("IDLE_stance");actor.reference_motion.time=0
 actor.actions.reaction_left=0;actor.actions.reloading=false;actor.actions.reload_weight=0;actor.actions.aim_weight=0;actor.actions.weapon_group="colt45"
 visual.sample_pose(0.3)
 var left_before:=visual.skeleton.get_bone_pose_rotation(left)
 actor.actions.aim_weight=1;actor.actions.upper_allowed=true;visual.sample_pose(0.3)
 check("pistol aiming leaves the left arm on its base pose",left_before.angle_to(visual.skeleton.get_bone_pose_rotation(left))<0.002,left_before.angle_to(visual.skeleton.get_bone_pose_rotation(left)))
 arena.set_physics_process(true)
 actor.respawn(Vector3(-28,0.94,38));await frames(25)
 actor.facing=0;actor.visual.rotation.y=0;arena.rig.yaw=PI;gun.cooldown=0;gun.reload_left=0;gun.magazine=gun.profile.magazine_size
 shots=gun.shots
 var hipfire:=GameplayCommand.new();hipfire.fire=true
 await frames(1,hipfire)
 check("hip fire outside arm range blocks an impossible backward shot",gun.shots==shots)
 await frames(30,hipfire)
 check("hip fire does not rotate the whole actor toward a backward target",gun.shots==shots and absf(actor.facing)<0.03)
 actor.facing=PI;actor.visual.rotation.y=PI
 await frames(20,hipfire)
 check("firing resumes when movement or aim faces within the arm cone",gun.shots>shots)
 arena.rig.yaw=0
 car.reset_at(Vector3(18,0.9,5));car.damage.repair();await frames(100)
 actor.respawn(Vector3(-28,0.94,38));await frames(20)
 var wheel:Node3D=car.wheel_visuals[0]
 var at:=wheel.global_position
 var hit:=BallisticTrace.cast(arena.get_world_3d().direct_space_state,at-Vector3.RIGHT*3,at+Vector3.RIGHT*0.1,[])
 check("bullet ray identifies the actual tire component",not hit.is_empty() and hit.collider is VehicleHitRegion and hit.collider.kind=="tire",hit.get("position"))
 if not hit.is_empty():DamageEvent.deliver(hit.collider,DamageEvent.make(25,hit.position,Vector3.RIGHT))
 await frames(20)
 check("tire hit persists without shrinking its visual mesh",car.damage.wheel_flat[0] and car.wheel_spinners[0].scale.is_equal_approx(Vector3.ONE),car.wheel_spinners[0].scale)
 var glass:VehicleHitRegion=car.damage.glass_region
 var mesh:MeshInstance3D=car.damage.windshield_ok.find_child("Geometry*",true,false)
 var glass_point:=mesh.global_transform*mesh.mesh.get_aabb().get_center()
 var front:=glass_point-car.global_basis.z*4
 hit=BallisticTrace.cast(arena.get_world_3d().direct_space_state,front,glass_point+car.global_basis.z,[])
 check("windshield ray resolves its own native glass region",not hit.is_empty() and hit.collider==glass,hit.get("position"))
 if not hit.is_empty():DamageEvent.deliver(hit.collider,DamageEvent.make(25,hit.position,car.global_basis.z))
 await frames(2)
 check("first glass hit selects cracked mesh",car.damage.glass_state=="cracked" and not car.damage.windshield_ok.visible and car.damage.windshield_damaged.visible)
 DamageEvent.deliver(glass,DamageEvent.make(25,glass_point,Vector3.BACK))
 await frames(2)
 check("second glass hit removes glass and its bullet volume",car.damage.glass_state=="shattered" and not car.damage.windshield_damaged.visible and glass.collision_layer==0)
 car.damage.repair();car.reset_at(Vector3(18,0.9,5));await frames(90)
 var seat:VehicleTransition=arena.transition
 actor.reset_at(car.approach_position(1));await frames(25)
 check("passenger-side approach reserves the right seat",seat.request_enter(car,true) and seat.seat_index==1 and seat.entry_side==1)
 await frames(ceili(seat.profile.enter_seconds*60)+10)
 check("passenger occupancy never grants driving control",seat.state=="passenger" and car.driver==null and car.seating.occupants.get(1)==actor)
 check("passenger can reserve a free driver seat for shuffle",seat.request_switch_driver())
 await frames(55)
 check("shuffle atomically transfers unique driver ownership",seat.state=="driving" and car.driver==actor and car.seating.occupants.size()==1)
 var vehicle_modes:=[]
 for i in range(4):
  var cycle:=GameplayCommand.new();cycle.camera_cycle=true;await frames(1,cycle)
  vehicle_modes.append(arena.rig.vehicle_mode)
 check("vehicle camera cycles follow distances and bonnet view",vehicle_modes==[2,3,0,1] and arena.rig.camera.global_position.is_finite(),vehicle_modes)
 check("driver exit can begin",seat.request_exit());await frames(ceili(seat.profile.exit_seconds*60)+10)
 check("exit releases every occupancy and reservation",seat.state=="on_foot" and car.seating.occupants.is_empty() and car.seating.reservations.is_empty())
 actor.reset_at(car.approach_position(1));await frames(25)
 check("right-side normal entry begins",seat.request_enter(car))
 await frames(ceili(seat.profile.enter_seconds*60)+60)
 check("normal right entry uses source shuffle to reach driver",seat.state=="driving" and car.driver==actor)
 seat.request_exit();await frames(ceili(seat.profile.exit_seconds*60)+10)
 actor.respawn(Vector3(-28,0.94,38));await frames(25)
 gun.equip_slot(unarmed)
 var victim:CharacterMotor=arena.pedestrians[0]
 for brain in arena.ped_brains:brain.set_physics_process(false)
 victim.respawn(actor.global_position+Vector3.FORWARD*1.2)
 var before:=victim.health.health
 var punch:=GameplayCommand.new();punch.fire=true
 await frames(1,punch);await frames(7)
 check("melee windup does not apply early damage",is_equal_approx(victim.health.health,before))
 await frames(10)
 var after:=victim.health.health
 check("melee strike window damages a nearby actor",after<before,{"before":before,"after":after})
 await frames(25)
 check("one swing cannot repeatedly damage its target",is_equal_approx(victim.health.health,after))
 for row in [[Vector3.BACK,"KO_shot_front"],[Vector3.FORWARD,"KO_skid_back"],[Vector3.RIGHT,"KO_spin_L"],[Vector3.LEFT,"KO_spin_R"]]:
  victim.respawn(Vector3(-24,0.94,35));victim.facing=0
  DamageEvent.deliver(victim,DamageEvent.make(10000,victim.global_position,row[0],"bullet",actor))
  check("directional death chooses "+row[1],victim.actions.life_clip==row[1],victim.actions.life_clip)
 victim.respawn(Vector3(-24,0.94,35));victim.stance.set_crouched(true)
 victim.reference_motion.force_action(victim.stance.profile.crouch_clip,0)
 victim.reference_motion.time=victim.reference_motion.duration(victim.stance.profile.crouch_clip)
 var victim_pose:SkinnedMotionVisual=victim.reference_pose;victim_pose.sample_pose(0.5)
 var head_point:=victim_pose.skeleton.global_transform*victim_pose.skeleton.get_bone_global_pose(victim_pose.skeleton.find_bone("Head")).origin
 DamageEvent.deliver(victim,DamageEvent.make(10000,head_point,Vector3.BACK,"bullet",actor))
 check("crouched head hits resolve against the posed head",victim.actions.life_clip=="KO_shot_face",victim.actions.life_clip)
 # Collision and combustion tests run without the player composition loop parking the car.
 arena.set_physics_process(false)
 actor.respawn(Vector3(-28,0.94,38))
 car.damage.repair();car.reset_at(Vector3(18,0.9,5));await frames(90)
 var wall:=LabGeometry.box(arena,Vector3(7,4,0.4),Vector3(18,2,-3),Color.GRAY,true)
 car.brake=0;car.linear_velocity=Vector3(0,0,-18)
 await frames(80)
 check("world collision removes meaningful vehicle health",car.damage.health<car.damage.profile.maximum_health,car.damage.health)
 var held_health:=car.damage.health
 await frames(60)
 check("resting wall contact does not repeatedly deal damage",absf(car.damage.health-held_health)<0.1,{"before":held_health,"after":car.damage.health})
 wall.queue_free();await frames(2)
 var losses:=[]
 for yaw in [0.0,PI*0.5]:
  car.damage.repair();car.reset_transform=Transform3D(Basis(Vector3.UP,yaw),Vector3(0,0.9,38));car.reset_pending=true;car.park();await frames(80)
  var direction:=Basis(Vector3.UP,yaw)*Vector3.FORWARD
  var fixture:=LabGeometry.box(arena,Vector3(7,4,0.4) if yaw==0 else Vector3(0.4,4,7),Vector3(0,2,38)+direction*8,Color.GRAY,true)
  await frames(2);car.brake=0;car.linear_velocity=direction*18
  await frames(80)
  losses.append(car.damage.profile.maximum_health-car.damage.health)
  fixture.queue_free();await frames(2)
 check("collision damage uses world normals under vehicle rotation",minf(losses[0],losses[1])>10 and absf(losses[0]-losses[1])<maxf(losses[0],losses[1])*0.03,losses)
 car.damage.repair();car.reset_at(Vector3(18,0.9,20));await frames(80)
 var dynamic_bin:=PhysicalProp.new();arena.add_child(dynamic_bin);dynamic_bin.global_position=Vector3(18,0.05,15.5);await frames(15)
 var bin_start:=dynamic_bin.global_position
 car.brake=0;car.linear_velocity=Vector3(0,0,-10);await frames(65)
 check("a car transfers physical momentum to a trash can",dynamic_bin.global_position.distance_to(bin_start)>1 and dynamic_bin.global_position.is_finite(),dynamic_bin.global_position.distance_to(bin_start))
 dynamic_bin.queue_free();await frames(2)
 car.damage.repair();car.reset_at(Vector3(18,0.9,20));await frames(80)
 var other:DriveVehicle=preload("res://scenes/vehicle.tscn").instantiate();arena.add_child(other);other.reset_at(Vector3(18,0.9,11));await frames(80)
 car.brake=0;car.linear_velocity=Vector3(0,0,-16);await frames(80)
 check("vehicle-to-vehicle impacts damage both bodies",car.damage.health<1000 and other.damage.health<1000,{"hitter":car.damage.health,"struck":other.damage.health})
 other.queue_free();await frames(2)
 car.damage.repair()
 DamageEvent.deliver(car,DamageEvent.make(800,car.global_position,Vector3.FORWARD))
 check("low vehicle health enters a timed burning state",car.damage.state=="burning")
 await frames(310)
 check("burning detonates once and disables drivetrain",car.damage.state=="destroyed" and car.damage.explosion_count==1 and car.throttle==0,car.damage.explosion_count)
 await frames(30)
 check("destroyed car cannot be reserved or explode twice",not car.reserve_seat(actor) and car.damage.explosion_count==1)
 arena.set_physics_process(true)
 actor.respawn(car.approach_position());await frames(30)
 var repair:=GameplayCommand.new();repair.repair_vehicle=true;await frames(1,repair)
 check("lab repair restores a nearby stopped wreck for continuous testing",car.damage.state=="healthy" and car.damage.health==car.damage.profile.maximum_health and car.damage.glass_state=="intact")
 var report:Dictionary={"engine":Engine.get_version_info().string,"backend":"Jolt Physics","assertions":results.size(),"failures":failures,"results":results,"metrics":metrics,"reference_runtime_parity":false}
 var file:=FileAccess.open("res://tests/systems_results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("RESULT systems ",results.size()," assertions / ",failures," failures")
 arena.queue_free();await process_frame;quit(1 if failures else 0)
