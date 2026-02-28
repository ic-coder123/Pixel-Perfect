extends Node

var unlocked_abilities = {
	"double_jump": false,
	"dash": false,
	"wall_jump": false
}

func unlock_ability(ability_name: String) -> void:
	if unlocked_abilities.has(ability_name):
		unlocked_abilities[ability_name] = true

# checkpoint/respawn state --------------------------------------------------

# world start location (optional, can be set by level or player)
var start_position : Vector2 = Vector2.ZERO

# last triggered checkpoint position; default to start
var last_checkpoint : Vector2 = Vector2.ZERO

func _ready():
	# ensure the start position matches the first call to set_checkpoint
	last_checkpoint = start_position

func set_checkpoint(pos : Vector2) -> void:
	last_checkpoint = pos

func get_checkpoint() -> Vector2:
	return last_checkpoint

func respawn_player(player: Node) -> void:
	# generic respawn helper - move player and clear velocity if available
	player.global_position = last_checkpoint
	if player.has_method("set_velocity"):
		player.set_velocity(Vector2.ZERO)
