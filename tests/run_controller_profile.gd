extends SceneTree
## Repeatable CPU sample, excluding rendering and the Jolt solver; no FPS claim.
var arena:Node3D
func _initialize()->void:run.call_deferred()
func frames(n:int,cmd:GameplayCommand)->void:
 arena.injected_command=cmd
 for i in range(n):await physics_frame;await process_frame
func run()->void:
 arena=load("res://scenes/arena.tscn").instantiate();arena.test_mode=true;arena.enable_vehicle_fixtures=false;root.add_child(arena)
 await frames(90,GameplayCommand.new())
 var samples:Array[Dictionary]=[]
 for scenario in ["idle","run","aim_fire"]:
  arena.actor.respawn(Vector3(-28,0.94,38));arena.actor.facing=0;arena.rig.yaw=0
  var cmd:=GameplayCommand.new()
  cmd.move=Vector2(0,-1) if scenario=="run" else Vector2.ZERO
  cmd.aim=scenario=="aim_fire";cmd.fire=cmd.aim
  await frames(30,cmd)
  arena.telemetry=GameplayTelemetry.new()
  await frames(240,cmd)
  var summary:Dictionary=arena.telemetry.summary();summary.scenario=scenario;samples.append(summary)
 var report:={"engine":Engine.get_version_info().string,"native_assets":arena.actor.reference_enabled,"samples":samples,"scope":"Headless CPU orchestration, player native pose and four pedestrian producers. Excludes render/GPU, Jolt solve, Android thermals; single local sample."}
 var file:=FileAccess.open("res://tests/controller_profile_results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("PROFILE ",JSON.stringify(report))
 arena.queue_free();await process_frame;quit()
