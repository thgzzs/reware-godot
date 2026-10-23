class_name LegacyPhysicsUnits
extends RefCounted
## Timer.cpp normalizes elapsed seconds by 50; velocity is metres/normalized tick.
const TICKS_PER_SECOND := 50.0
const PED_MASS_KG := 70.0
static func velocity(source: float) -> float: return source*TICKS_PER_SECOND
static func acceleration(source: float) -> float: return source*TICKS_PER_SECOND*TICKS_PER_SECOND
static func impulse(source: float) -> float: return source*TICKS_PER_SECOND
static func player_jump_speed() -> float: return impulse(8.5)/PED_MASS_KG
static func jump_forward(intensity: float, sprint: bool) -> float:
 var blend := clampf(intensity-1.0,0,1)
 return velocity(0.17+0.05) if sprint else velocity(0.10+0.07*blend)
