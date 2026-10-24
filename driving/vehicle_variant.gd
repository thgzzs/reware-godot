class_name VehicleVariant
extends Resource
@export var id := "idaho"
@export var handling_id := "IDAHO"
@export var model_scene := "res://assets/converted/models/idaho.scn"
@export var diagnostic_only := false
@export_enum("car","bike") var kind := "car"
@export var bike_animation := "BIKEs"
@export var bike_bailout_release_seconds := 0.24
@export var bike_bailout_suffix := "_getoffBACK"
@export var bike_bailout_fallbacks := PackedStringArray(["BIKE_fall_off","BIKE_fallR"])
@export var door_count := 2
@export var seat_count := 2
@export var display_color := Color(0.35,0.55,0.65)

func bailout_clip(prefix: String, actions: ActorActionState) -> String:
 var specific:=actions.resolve(PackedStringArray([prefix+bike_bailout_suffix]))
 if not specific.is_empty():return specific
 var fallback:=actions.resolve(bike_bailout_fallbacks)
 return fallback if not fallback.is_empty() else prefix+bike_bailout_suffix
