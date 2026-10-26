class_name TraversalCourse
extends Node3D
## Named static fixtures; no per-frame map script or invisible catch floor.
@export var profile:TraversalCourseProfile=preload("res://tuning/traversal_course.tres")
var slopes:Array[StaticBody3D]=[]
var garden:Array[StaticBody3D]=[]
var void_platforms:Array[StaticBody3D]=[]
var drop_decks:Array[StaticBody3D]=[]
var materials:Dictionary={}
func _ready() -> void:
 name="TraversalCourse"
 build_slopes();build_garden();build_drop_tower();build_void_loop()
func block(id:String,size:Vector3,at:Vector3,color:Color,solid:=true) -> Node3D:
 var body:=LabGeometry.box(self,size,at,color,solid)
 body.name=id
 var mesh:MeshInstance3D=body.get_child(1) if solid else body
 if not materials.has(color):materials[color]=mesh.material_override
 mesh.material_override=materials[color]
 return body
func signpost(value:String,at:Vector3,size:=24) -> void:
 var label:=LabGeometry.label(self,value,at,size)
 label.no_depth_test=false
func deck(id:String,at:Vector3,size:Vector2,color:Color,thickness:=0.3) -> StaticBody3D:
 return block(id,Vector3(size.x,thickness,size.y),at-Vector3.UP*thickness*0.5,color) as StaticBody3D
func build_slopes() -> void:
 signpost("04 / SLOPE GALLERY — WALK UP / SLIDE BACK",Vector3(-8,3,-52),30)
 for i in range(profile.slope_angles.size()):
  var angle:float=profile.slope_angles[i]
  var radians:=deg_to_rad(angle)
  var rise:=tan(radians)*profile.slope_run
  var front:=profile.slope_start+Vector3.RIGHT*i*profile.slope_spacing
  var color:=Color("739c95") if angle<=40 else Color("bf8560")
  var ramp:=block("Slope%02d"%int(angle),Vector3(profile.slope_width,0.2,profile.slope_run/cos(radians)),front+Vector3(0,rise*0.5-0.1*cos(radians),-profile.slope_run*0.5),color) as StaticBody3D
  ramp.rotation.x=radians;ramp.set_meta("angle_degrees",angle);slopes.append(ramp)
  deck("SlopeDeck%02d"%int(angle),front+Vector3(0,rise,-profile.slope_run-1),Vector2(profile.slope_width,2),color)
  signpost("%d° / %.1f m"%[int(angle),rise],front+Vector3(0,1,1.3),23)
func build_garden() -> void:
 signpost("05 / PLATFORM GARDEN — STEP / JUMP / LAND",Vector3(-18,3.9,64),28)
 for i in range(profile.garden_route.size()):
  var at:Vector3=profile.garden_route[i]
  garden.append(block("Garden%02d"%i,Vector3(profile.garden_size.x,at.y,profile.garden_size.y),Vector3(at.x,at.y*0.5,at.z),Color("849faf")) as StaticBody3D)
  signpost("%02d / %.2f m"%[i+1,at.y],at+Vector3(0,0.22,1.05),17)
 for i in range(4):
  var height:float=[0.12,0.24,0.32,0.42][i]
  block("StepGauge%02d"%i,Vector3(2.2,height,2.2),Vector3(-29+i*3.2,height*0.5,68),Color("b9ae8e"))
  signpost("%.2f m"%height,Vector3(-29+i*3.2,height+0.6,68),18)
func build_drop_tower() -> void:
 signpost("06 / IMPACT TOWER — 1 / 2 / 4 / 7 m",Vector3(54,3,34),30)
 block("EastAccess",Vector3(12,0.03,5),Vector3(42,0.02,36),Color("a7aa87"),false)
 for i in range(profile.tower_steps):
  var h:float=(i+1)*profile.tower_riser
  block("TowerStep%02d"%i,Vector3(profile.tower_tread,h,2.6),profile.tower_start+Vector3((i+0.5)*profile.tower_tread,h*0.5,0),Color("9eaaa6"))
  if i+1 in [4,8,16,28]:
   var at:=profile.tower_start+Vector3((i+0.5)*profile.tower_tread,h,-3.5)
   drop_decks.append(deck("DropDeck%02d"%int(h),at,Vector2(2.6,5),Color("b99375")))
   signpost("DROP / %d m"%int(h),at+Vector3(0,0.8,-1.8),23)
   block("LandingMat%02d"%int(h),Vector3(3,0.025,4),Vector3(at.x,0.02,at.z-5),Color("b5b4a0"),false)
func build_void_loop() -> void:
 signpost("07 / VOID LOOP — FALLING RETURNS YOU TO SPAWN",Vector3(-3,3.6,72),27)
 for i in range(profile.void_route.size()):
  var at:Vector3=profile.void_route[i]
  void_platforms.append(deck("VoidPlatform%02d"%i,at,profile.void_size,Color("778eaa") if i%2==0 else Color("b7a687")))
  signpost("%02d"%(i+1),at+Vector3(0,0.15,0),18)
