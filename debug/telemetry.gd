class_name GameplayTelemetry
extends RefCounted
const CAPACITY := 3600
var ticks := 0
var samples := PackedFloat64Array()
var cursor := 0
var maximum_us := 0.0
func _init() -> void:
 samples.resize(CAPACITY)
func record(duration_us: float) -> void:
 samples[cursor] = duration_us
 cursor = (cursor+1)%CAPACITY
 ticks += 1
 maximum_us = maxf(maximum_us,duration_us)
func summary() -> Dictionary:
 var values := Array(samples.slice(0,mini(ticks,CAPACITY)))
 if values.is_empty(): return {}
 values.sort()
 var total := 0.0
 for value in values: total += value
 return {"samples":values.size(),"mean_us":total/values.size(),"p95_us":values[int((values.size()-1)*0.95)],"max_us":maximum_us,"scope":"gameplay orchestration only; excludes Jolt solve and rendering"}
