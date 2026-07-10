extends TextureProgressBar

@onready var player = get_parent().get_parent()

func _ready() -> void:
	if player:
		
		
		
		value = player.health
		print("Health bar initialized. Max: ", max_value, " Current: ", value)
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if player:
		# Continuously sync value to handle cases where signals might be missed 
		# or health is modified directly (like at checkpoints)
		if value != player.health:
			value = player.health
			print("Health bar visual synced to: ", value)



func _took_damage() -> void:
	value = player.health
	print("Health bar updated. Current health: ", value)