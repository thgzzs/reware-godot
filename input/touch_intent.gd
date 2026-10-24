class_name TouchIntent
extends RefCounted
## Touch ownership stays in the UI; commands use the existing actor/vehicle boundary.
var profile:TouchProfile=preload("res://tuning/touch.tres")
var move:=Vector2.ZERO
var look:=Vector2.ZERO
var held:Dictionary={}
var edges:Dictionary={}
var aim_latched:=false
var driving:=false
func press(action:String) -> void:
 held[action]=int(held.get(action,0))+1
 edges[action]=true
 if action=="aim" and profile.aim_toggle:aim_latched=not aim_latched
func release(action:String) -> void:
 held[action]=maxi(0,int(held.get(action,0))-1)
func down(action:String) -> bool:return int(held.get(action,0))>0
func clear() -> void:
 move=Vector2.ZERO;look=Vector2.ZERO;held.clear();edges.clear();aim_latched=false
func apply(cmd:GameplayCommand) -> GameplayCommand:
 var axis:=Vector2(move.x,0) if driving else move
 if driving:axis.y=float(down("reverse"))-float(down("throttle"))
 cmd.move=(cmd.move+axis).limit_length(1)
 cmd.look+=look*profile.look_gain
 cmd.fire=cmd.fire or down("fire") or edges.has("fire")
 cmd.aim=cmd.aim or (aim_latched if profile.aim_toggle else down("aim"))
 cmd.sprint=cmd.sprint or down("sprint")
 cmd.brake=cmd.brake or down("brake")
 cmd.walk=cmd.walk or down("walk")
 for action in ["jump","interact","reload","crouch","camera_cycle","switch_seat","repair_vehicle","respawn"]:
  if edges.has(action):cmd.set(action,true)
 cmd.sprint_pressed=cmd.sprint_pressed or edges.has("sprint")
 cmd.weapon_step+=int(edges.has("weapon_next"))-int(edges.has("weapon_previous"))
 edges.clear();look=Vector2.ZERO
 return cmd
