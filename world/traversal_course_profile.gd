class_name TraversalCourseProfile
extends Resource
## Y is the platform top surface, in metres. All fixtures use real collision.
@export var slope_angles:=PackedFloat32Array([10,20,30,40,50,60])
@export var slope_start:=Vector3(-25,0,-56)
@export var slope_spacing:=7.0
@export var slope_run:=5.0
@export var slope_width:=3.6
@export var garden_route:=PackedVector3Array([Vector3(-25,0.25,60),Vector3(-25,0.55,56),Vector3(-25,0.9,52),Vector3(-21,1.25,52),Vector3(-17,1.65,52),Vector3(-13,2.1,52),Vector3(-9,2.6,52)])
@export var garden_size:=Vector2(2.8,2.8)
@export var tower_start:=Vector3(45,0,28)
@export var tower_riser:=0.25
@export var tower_tread:=0.60
@export var tower_steps:=28
@export var void_route:=PackedVector3Array([Vector3(0,0.3,73.5),Vector3(0,0.6,78),Vector3(3,0.95,82),Vector3(6,1.3,86),Vector3(6,1.75,90),Vector3(2,2.15,94),Vector3(-2,2.55,98),Vector3(-6,2.55,98),Vector3(-8,2.1,94),Vector3(-8,1.65,90),Vector3(-8,1.2,86),Vector3(-5,0.8,82),Vector3(-3,0.4,78)])
@export var void_size:=Vector2(3.0,3.0)
