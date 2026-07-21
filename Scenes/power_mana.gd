extends TextureProgressBar

@onready var player = get_parent().get_parent()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	value = 0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if player:
		value = player.display_mana
