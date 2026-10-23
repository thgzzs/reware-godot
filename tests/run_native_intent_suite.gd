extends SceneTree
## Uses the supplied skin and VCS/LCS animation library, never fixture clips.
var arena:Node3D
var results:Array[Dictionary]=[]
var failures:=0
var metrics:={}
func _initialize() -> void:run.call_deferred()
func frames(count:int,cmd:GameplayCommand=null) -> void:
 arena.injected_command=cmd if cmd!=null else GameplayCommand.new()
 for i in range(count):await physics_frame;await process_frame
func check(label:String,passed:bool,value:Variant=null) -> void:
 results.append({"name":label,"passed":passed,"measured":value})
 if not passed:failures+=1
 print("PASS " if passed else "FAIL ",label," ",value)
func skin_bounds() -> AABB:
 var visual:SkinnedMotionVisual=arena.actor.reference_pose
 var minimum:=Vector3(INF,INF,INF);var maximum:=-minimum
 for mesh in visual.find_children("*","MeshInstance3D",true,false):
  if mesh.skin==null:continue
  for surface in range(mesh.mesh.get_surface_count()):
   var arrays:Array=mesh.mesh.surface_get_arrays(surface)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
   var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
   for i in range(vertices.size()):
    var p:=Vector3.ZERO
    for j in range(4):
     var bind:=bones[i*4+j]
     p+=visual.skeleton.get_bone_global_pose(mesh.skin.get_bind_bone(bind))*mesh.skin.get_bind_pose(bind)*vertices[i]*weights[i*4+j]
    p=visual.global_transform*p;minimum=minimum.min(p);maximum=maximum.max(p)
 return AABB(minimum,maximum-minimum)
func until_state(state:String,maximum:=650) -> void:
 for i in range(maximum):
  if arena.transition.state==state:return
  await frames(1)
func run() -> void:
 arena=preload("res://scenes/arena.tscn").instantiate();arena.test_mode=true;root.add_child(arena)
 await frames(90)
 for brain in arena.ped_brains:brain.set_physics_process(false)
 var actor:CharacterMotor=arena.actor
 check("supplied native player and animation library activated",actor.reference_pose is SkinnedMotionVisual and actor.reference_motion.library.get_animation_list().size()==1168)
 actor.respawn(Vector3(-25,0.94,65));actor.facing=0;await frames(30)
 var cmd:=GameplayCommand.new();cmd.move=Vector2(0,-1);cmd.sprint=true;await frames(75,cmd)
 var minimum:=INF;var maximum:=0.0;var continuous:=true;var lowest_boosted:=INF;var advance_count:=0;var old_time:=actor.reference_motion.time
 for i in range(300):
  cmd.sprint=i%16<8;await frames(1,cmd)
  var speed:=Vector2(actor.velocity.x,actor.velocity.z).length()
  minimum=minf(minimum,speed);maximum=maxf(maximum,speed)
  if i>150:lowest_boosted=minf(lowest_boosted,actor.sprint.multiplier)
  continuous=continuous and actor.reference_motion.phase=="move" and actor.reference_motion.clip=="sprint_civi"
  if not is_equal_approx(old_time,actor.reference_motion.time):advance_count+=1
  old_time=actor.reference_motion.time
 metrics.sprint={"minimum_mps":minimum,"maximum_mps":maximum,"minimum_late_multiplier":lowest_boosted,"moving_ticks":advance_count}
 check("native sprint taps retain one gait without stop or walk-start",continuous,metrics.sprint)
 check("native sprint root motion never stalls between taps",minimum>1 and advance_count==300)
 check("native sprint tap boost remains capped",actor.sprint.multiplier<=actor.sprint.profile.maximum_multiplier and lowest_boosted>1.10,actor.sprint.multiplier)
 for id in ["Idaho","pcj600","sanchez","faggio","freeway"]:
  var car:DriveVehicle=arena.vehicle if id=="Idaho" else arena.get_node(id)
  car.freeze=true
  actor.respawn(car.approach_position()+Vector3(-0.75,0,0.35));actor.facing=0;await frames(35)
  var accepted:bool=arena.transition.request_enter(car)
  check("native walk-in reserves "+id,accepted and arena.transition.state=="approaching")
  var last:=actor.global_position;var max_step:=0.0;var walked:=0.0
  for i in range(650):
   if arena.transition.state!="approaching":break
   await frames(1);var step:=actor.global_position.distance_to(last);walked+=step;max_step=maxf(max_step,step);last=actor.global_position
  check("native walk reaches mount before animation "+id,arena.transition.state=="entering" and walked>0.5 and max_step<0.10,{"distance":walked,"maximum_step":max_step,"state":arena.transition.state})
  await until_state("driving")
  check("native entry commits sole driver "+id,arena.transition.state=="driving" and car.driver==actor and car.reservation==null)
  if arena.transition.state=="driving":
   if car.kind=="bike":
    var expected:=car.bike_animation+"_getoffBACK"
    check("supplied bike rear bailout clip resolves "+id,actor.reference_motion.library.has_animation(expected) and car.variant.bailout_clip(car.bike_animation,actor.actions)==expected,expected)
    var bailed:bool=arena.transition.request_eject()
    await frames(5)
    check("native bike windup holds ownership "+id,bailed and arena.transition.state=="ejecting" and car.driver==actor and actor.reference_motion.clip==expected)
    await frames(15)
    check("native bike releases into Jolt exactly once "+id,arena.transition.state=="on_foot" and car.driver==null and actor.reaction_body.active)
   else:
    arena.transition.request_exit();await until_state("on_foot")
  if arena.transition.state!="on_foot":arena.transition.recover()
  car.freeze=false
 for direction in [Vector3.FORWARD,Vector3.BACK]:
  actor.respawn(Vector3(-25,3,35));actor.facing=0;actor.health.receive(10000)
  actor.reaction_body.launch_velocity(actor.global_position,0,direction*4)
  await frames(20)
  check("native fall preserves airborne spin "+str(direction),not actor.reaction_body.rest.locked and actor.reaction_body.rest.weight==0)
  await frames(280)
  var bounds:=skin_bounds()
  var sample:={"minimum_y":bounds.position.y,"height":bounds.size.y,"clip":actor.actions.life_clip,"heading":actor.reaction_body.rest.heading,"face_down":actor.reaction_body.rest.face_down}
  metrics["prone" if direction==Vector3.FORWARD else "supine"]=sample
  check("native quiet fall chooses matching terminal pose "+str(direction),actor.reaction_body.rest.locked and actor.reaction_body.rest.face_down==(direction==Vector3.FORWARD) and bounds.size.y<0.65,sample)
  check("native settled skin clears floor without hovering "+str(direction),bounds.position.y>=-0.035 and bounds.position.y<0.05,sample)
  var visual:SkinnedMotionVisual=actor.reference_pose
  var chest:=visual.global_basis*(-visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("Spine1")).basis.z)
  check("native chest faces the intended floor/sky direction "+str(direction),chest.y*(-1 if direction==Vector3.FORWARD else 1)>0.8,chest.y)
 for direction in [Vector3(3,0,-3),Vector3(-3,0,3)]:
  actor.respawn(Vector3(-25,2,35));actor.facing=0;actor.actions.begin_life("down");actor.control_enabled=false
  actor.reaction_body.launch_velocity(actor.global_position,0,direction)
  var expected:="GETUP_front" if direction.z<0 else "GETUP"
  var recovered:=false
  for i in range(500):
   await frames(1)
   if actor.actions.life=="getting_up":recovered=true;break
  check("native recovery selects matching get-up "+str(direction),recovered and actor.actions.life_clip==actor.actions.resolve(PackedStringArray([expected])),actor.actions.life_clip)
  await frames(180)
  check("native recovery preserves fallen heading "+str(direction),actor.control_enabled and absf(angle_difference(actor.facing,-PI/4))<0.05,actor.facing)
 var report:={"engine":Engine.get_version_info().string,"backend":"Jolt Physics","assertions":results.size(),"failures":failures,"results":results,"metrics":metrics,"assets":"supplied native skin, VCS core and LCS bike clips","reference_runtime_parity":false}
 var file:=FileAccess.open("res://tests/native_intent_results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("RESULT native intent ",results.size()," / failures ",failures)
 arena.queue_free();await process_frame;quit(1 if failures else 0)
