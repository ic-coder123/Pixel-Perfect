extends TextureProgressBar

@onready var player = get_parent().get_parent()

func _ready() -> void:
	if player:
		value = player.display_health
		print("Health bar initialized. Max: ", max_value, " Current: ", value)
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if player:
		value = player.display_health



func _took_damage() -> void:
	value = player.display_health
	print("Health bar updated. Current health: ", value)
