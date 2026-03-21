extends Control

var is_accepting_input = false

var updating_key = ""
var updating_button: Button = null



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for child in get_children():
		if "input_id" in child:
			var target_button = child.button_name if child.button_name else child
			_update_button_text(target_button, child.input_id)
			child.pressed.connect(_on_button_pressed.bind(child))

func _on_button_pressed(button: Button) -> void:
	is_accepting_input = true
	updating_key = button.input_id
	updating_button = button.button_name if button.button_name else button
	updating_button.text = "Press Key..."

	

func _input(event: InputEvent) -> void:
	if is_accepting_input:
		if (event is InputEventKey or event is InputEventMouseButton) and event.pressed :
			InputMap.action_erase_events(updating_key)
			InputMap.action_add_event(updating_key, event)
			
			_update_button_text(updating_button, updating_key)
			
			is_accepting_input = false
			updating_key = ""
			updating_button = null
			get_viewport().set_input_as_handled()

func _update_button_text(button: Button, action: String) -> void:
	var events = InputMap.action_get_events(action)
	if events.size() > 0:
		button.text = events[0].as_text()
	else:
		button.text = "Unbound"



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
