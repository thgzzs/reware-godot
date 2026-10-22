class_name ImportedGameplayDatabase
extends Resource
## Source fields retain their units. Only explicitly mapped fields drive gameplay.
@export var ped_stats: Array[Dictionary] = []
@export var weapons: Array[Dictionary] = []
@export var fight_moves: Array[Dictionary] = []
@export var ped_groups: Array[Dictionary] = []
@export var ped_types: Array[Dictionary] = []
@export var handling: Array[Dictionary] = []
@export var special_handling: Array[Dictionary] = []
func find_record(table: String, key: String) -> Dictionary:
 for record in get(table):
  if record.get("name","")==key: return record
 return {}
