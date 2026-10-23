extends SceneTree
var arena:Node3D
var label:="60"
class Driver:
 extends Node
 var arena:Node3D
 var app:SceneTree
 var tick:=0
 var snapshots:Array[Dictionary]=[]
 var render_steps:=0
 var min_render_dt:=INF
 var max_render_dt:=0.0
 var variable:=false
 func _process(dt:float) -> void:
  render_steps+=1
  min_render_dt=minf(min_render_dt,dt)
  max_render_dt=maxf(max_render_dt,dt)
 func _physics_process(_dt:float) -> void:
  var actor:CharacterMotor=arena.actor
  if tick==60:actor.respawn(Vector3(-28,0.94,38));actor.facing=0;actor.visual.rotation.y=0
  if variable:Engine.max_fps=[30,144,60,120][(tick/90)%4]
  var cmd:=GameplayCommand.new()
  if tick>=90 and tick<400:
   cmd.move=Vector2(0,-1)
   cmd.walk=tick<150
   cmd.sprint=tick>=260
  cmd.jump=tick in [151,301]
  if tick>=420 and tick<465:cmd.aim=true;cmd.fire=true
  if tick==480:cmd.crouch=true
  if tick>=490 and tick<525:cmd.aim=true;cmd.fire=true
  if tick==550:cmd.crouch=true
  arena.injected_command=cmd
  if tick>=90 and tick%30==0:
   var visual:SkinnedMotionVisual=actor.reference_pose
   var thigh:=visual.skeleton.find_bone("R Thigh")
   var q:=visual.skeleton.get_bone_pose_rotation(thigh)
   var p:=actor.global_position
   var v:=actor.velocity
   var car:DriveVehicle=arena.vehicle
   snapshots.append({"tick":tick,"position":[p.x,p.y,p.z],"velocity":[v.x,v.y,v.z],"phase":actor.phase,"clip":actor.reference_motion.clip,"pose":[q.x,q.y,q.z,q.w],"shots":arena.weapon.shots,"car":[car.global_position.x,car.global_position.y,car.global_position.z]})
  tick+=1
  if tick>600:
   set_physics_process(false)
   app.finish.call_deferred({"snapshots":snapshots,"render_steps":render_steps,"render_dt_range":[min_render_dt,max_render_dt],"physics_hz":Engine.physics_ticks_per_second})
func _initialize() -> void:run.call_deferred()
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--case="):label=arg.trim_prefix("--case=")
 arena=preload("res://scenes/arena.tscn").instantiate();arena.test_mode=true;arena.enable_vehicle_fixtures=false;root.add_child(arena)
 var driver:=Driver.new();driver.arena=arena;driver.app=self;driver.variable=label=="variable";driver.process_physics_priority=-100;root.add_child(driver)
func finish(report:Dictionary) -> void:
 report.engine=Engine.get_version_info().string
 report.case=label
 var f:=FileAccess.open("res://tests/timing_"+label+".json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("RESULT timing ",label," physics_hz=",report.physics_hz," snapshots=",report.snapshots.size()," render_steps=",report.render_steps)
 arena.queue_free();await process_frame;quit()
