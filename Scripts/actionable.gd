extends Area2D

@export var dialogue_resource = ""

func action() -> void:
	# Prevent starting a new dialogue if one is already active
	if Dialogic.current_timeline != null:
		return
	
	if dialogue_resource != "":
		Dialogic.start(dialogue_resource)
	else:
		push_warning("Actionable: No dialogue resource assigned.")