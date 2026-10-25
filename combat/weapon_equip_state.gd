class_name WeaponEquipState
extends RefCounted
## One attachment commit between lowering the old pose and raising the new one.
var lower_seconds := 0.14
var raise_seconds := 0.10
var phase := "ready"
var elapsed := 0.0
var slot := -1
var source: WeaponProfile
func busy() -> bool: return phase!="ready"
func begin(index:int, previous:WeaponProfile) -> void:
 slot=index;source=previous;phase="lowering";elapsed=0
func reset() -> void:
 phase="ready";elapsed=0;slot=-1;source=null
func pose_weight() -> float:
 if phase=="lowering":return 0.0
 if phase=="raising":return smoothstep(0,1,clampf(elapsed/maxf(0.001,raise_seconds),0,1))
 return 1.0
