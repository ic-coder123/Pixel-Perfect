extends "res://Scripts/enemy.gd"

# Starter enemy specific properties
@export var SPEED := 100.0
@export var DASH_SPEED := 600.0
@export var direction := -1
@export var gravity := 980.0
@export var TELEGRAPH_DURATION := 0.5
@export var DASH_ACCEL_DURATION := 0.6
@export var TELEGRAPH_VIBRATION := 2.0

var is_telegraphing := false
var is_dashing := false
var dash_velocity := 0.0
var dash_target_x := 0.0

func _handle_movement(delta: float) -> void:
	# Add gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	if is_telegraphing:
		velocity.x = 0
		# Telegraph vibration effect
		sprite.position.x = randf_range(-TELEGRAPH_VIBRATION, TELEGRAPH_VIBRATION)
	elif is_dashing:
		velocity.x = direction * dash_velocity
		sprite.position.x = 0

		# End the dash if we reach or overshoot the target X coordinate or hit a wall
		var reached = (direction > 0 and global_position.x >= dash_target_x) or (direction < 0 and global_position.x <= dash_target_x)
		if reached or is_on_wall():
			is_dashing = false
	else:
		sprite.position.x = 0

		# Patrol logic: turn at edges
		if is_on_floor():
			if not edge_detector.is_colliding():
				_turn_around()
			elif wall_detector.is_colliding():
				_turn_around()

		velocity.x = direction * SPEED

func _handle_detection(delta: float) -> void:
	# Check for player detection to start dash sequence
	if dash_initiater.is_colliding():
		var collider = dash_initiater.get_collider()
		if collider and collider.is_in_group("player"):
			_trigger_telegraph()

func _turn_around() -> void:
	direction *= -1
	# Flip the positions and targets of the raycasts to face the new direction
	edge_detector.position.x = abs(edge_detector.position.x) * direction
	edge_detector.target_position.x = abs(edge_detector.target_position.x) * direction
	dash_initiater.position.x = abs(dash_initiater.position.x) * direction
	dash_initiater.target_position.x = abs(dash_initiater.target_position.x) * direction
	# Flip the sprite to face the new direction
	sprite.flip_h = direction > 0

func _trigger_telegraph() -> void:
	if is_telegraphing or is_dashing:
		return
	is_telegraphing = true

	# Wait for telegraph duration
	await get_tree().create_timer(TELEGRAPH_DURATION).timeout
	is_telegraphing = false
	_start_dash()

func _start_dash() -> void:
	is_dashing = true
	dash_velocity = SPEED
	dash_target_x = dash_initiater.to_global(dash_initiater.target_position).x

	# Tween the speed from normal SPEED up to DASH_SPEED for a smooth acceleration
	var tween = create_tween()
	tween.tween_property(self, "dash_velocity", DASH_SPEED, DASH_ACCEL_DURATION).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)