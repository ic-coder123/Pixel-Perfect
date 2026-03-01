extends Area2D

@export var dialogue_resource = ""

func action() -> void:
	Dialogic.start(dialogue_resource)