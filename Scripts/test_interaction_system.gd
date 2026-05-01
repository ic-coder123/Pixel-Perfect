extends Node

## Unit Test: Interaction System Integrity
## This script verifies that the InputMap and Actionable detection remain functional.

func run_tests():
	print("--- Starting Interaction System Tests ---")
	test_input_map_state()
	test_actionable_detection_logic()
	print("--- Tests Complete ---")

## Verifies that 'ui_accept' is correctly mapped and has events.
func test_input_map_state():
	print("Testing InputMap...")
	var actions_to_check = ["ui_accept", "interact"]
	
	for action in actions_to_check:
		if not InputMap.has_action(action):
			printerr("[FAIL] Action '", action, "' is missing from InputMap!")
			continue
			
		var events = InputMap.action_get_events(action)
		if events.size() == 0:
			printerr("[FAIL] Action '", action, "' has ZERO events assigned. 'Set to Default' wiped it!")
		else:
			var event_names = events.map(func(e): return e.as_text())
			print("[PASS] '", action, "' is valid. Current keys: ", event_names)


## Verifies that the detection area on the player is actually working.
func test_actionable_detection_logic():
	print("Testing Actionable Detection...")
	
	# Setup a mock detection scenario
	var player_finder = Area2D.new()
	var collision = CollisionShape2D.new()
	collision.shape = CircleShape2D.new()
	player_finder.add_child(collision)
	
	var actionable = Area2D.new()
	var act_collision = CollisionShape2D.new()
	act_collision.shape = CircleShape2D.new()
	actionable.add_child(act_collision)
	
	# Add to tree to allow physics overlap check
	get_tree().root.add_child(player_finder)
	get_tree().root.add_child(actionable)
	
	actionable.global_position = player_finder.global_position
	
	# Force a physics update to check overlap immediately
	await get_tree().physics_frame
	
	if player_finder.get_overlapping_areas().size() > 0:
		print("[PASS] Actionable area detected correctly.")
	else:
		printerr("[FAIL] Actionable area not detected. Check collision layers/masks.")

	player_finder.queue_free()
	actionable.queue_free()