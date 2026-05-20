extends Node

var unlocked_abilities = {
	"double_jump": false,
	"dash": false,
	"wall_jump": false
}
# Add these variables to the top of Main.gd
var enemy_spawn_configs: Array = []
var _is_init_phase: bool = true

func register_enemy_spawn(path: String, pos: Vector2) -> void:
	# Only register the "original" enemies placed in the level editor
	if _is_init_phase:
		enemy_spawn_configs.append({"path": path, "pos": pos})

func respawn_all_enemies() -> void:
	_do_respawn_all_enemies.call_deferred()

func _do_respawn_all_enemies() -> void:
	# Stop new enemies from registering themselves during the respawn process
	_is_init_phase = false

	# 1. Remove all current enemies in the group
	get_tree().call_group("enemy", "queue_free")

	# 2. Re-create them from the saved blueprints
	for config in enemy_spawn_configs:
		var enemy_scene = load(config.path)
		if enemy_scene:
			var instance = enemy_scene.instantiate()
			instance.global_position = config.pos
			get_tree().current_scene.add_child(instance)


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
	load_input_data()

func set_checkpoint(pos : Vector2) -> void:
	last_checkpoint = pos

func get_checkpoint() -> Vector2:
	return last_checkpoint

func respawn_player(player: Node) -> void:
	# generic respawn helper - move player and clear velocity if available
	player.global_position = last_checkpoint
	if player.has_method("set_velocity"):
		player.set_velocity(Vector2.ZERO)

const INPUT_SETTINGS_PATH = "user://input_settings.cfg"

func save_input_data() -> void:
	var config = ConfigFile.new()
	for action in InputMap.get_actions():
		var events = InputMap.action_get_events(action)
		config.set_value("input", action, events)
	config.save(INPUT_SETTINGS_PATH)

func load_input_data() -> void:
	var config = ConfigFile.new()
	if config.load(INPUT_SETTINGS_PATH) == OK:
		for action in config.get_section_keys("input"):
			if InputMap.has_action(action):
				InputMap.action_erase_events(action)
				var events = config.get_value("input", action)
				for event in events:
					InputMap.action_add_event(action, event)
