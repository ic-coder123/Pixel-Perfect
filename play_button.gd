extends Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect the signal so the code runs when the user actually clicks
	pressed.connect(_on_play_pressed)

func _on_play_pressed() -> void:
	print("Play button pressed! Transitioning to main scene.")
	# Use call_deferred to safely change the scene after the current frame processing
	get_tree().change_scene_to_file.call_deferred("res://Scenes/World.tscn")



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
