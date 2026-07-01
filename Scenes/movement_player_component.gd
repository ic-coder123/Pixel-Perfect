class_name MovementPlayerComponent
extends Node

@export var SPEED := 300.0
@export var JUMP_VELOCITY := -480.0

@export var COYOTE_TIME := 0.2
@export var JUMP_BUFFER_TIME := 0.18

@export var WALL_COYOTE_TIME := 0.12
@export var WALL_JUMP_PUSH := 340.0
@export var WALL_JUMP_UP := -420.0
@export var WALL_SLIDE_MAX_FALL_SPEED := 220.0
@export var DASH_SPEED_MULTIPLIER := 3
@export var DASH_FRICTION := 0.1
@export var GROUND_FRICTION := 5.0
@export var JUMP_CUT_MULTIPLIER := 0.5
@export var LAND_SQUASH_X := 4.3
@export var LAND_SQUASH_Y := 3.7

var facing_direction := 1.0
var knockback_timer := 0.0

var coyote_timer := 0.0
var wall_coyote_timer := 0.0
var jump_buffer_timer := 0.0

var double_jump_used := false
var dash_timer := 0.0

var last_wall_normal := Vector2.ZERO
var was_in_air := false

var player: CharacterBody2D
var state_machine: Node
var animated_sprite: AnimatedSprite2D


func setup(p: CharacterBody2D, sm: Node, sprite: AnimatedSprite2D) -> void:
	player = p
	state_machine = sm
	animated_sprite = sprite


func update_timers(delta: float) -> void:
	knockback_timer = max(knockback_timer - delta, 0.0)

	if Input.is_action_just_pressed("up"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

	if player.is_on_floor():
		coyote_timer = COYOTE_TIME
		double_jump_used = false
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	if player.unlocked_abilities.get("wall_jump", false) and player.is_on_wall_only():
		var n := player.get_wall_normal()
		if abs(n.x) > 0.6:
			last_wall_normal = n
			wall_coyote_timer = WALL_COYOTE_TIME
	else:
		wall_coyote_timer = max(wall_coyote_timer - delta, 0.0)


func update_landing() -> void:
	if player.is_on_floor() and was_in_air:
		apply_landing_squash()
	was_in_air = not player.is_on_floor()


func apply_landing_squash() -> void:
	var land_tween = create_tween()
	land_tween.tween_property(animated_sprite, "scale", Vector2(LAND_SQUASH_X, LAND_SQUASH_Y), 0.1).set_trans(Tween.TRANS_SINE)
	land_tween.tween_property(animated_sprite, "scale", Vector2(4.0, 4), 0.1).set_trans(Tween.TRANS_SINE)


func apply_knockback(velocity: Vector2) -> void:
	player.velocity = velocity
	knockback_timer = 0.25


func apply_pogo_bounce() -> void:
	player.velocity.y = JUMP_VELOCITY
	double_jump_used = false


func handle_horizontal_movement(delta: float) -> void:
	var direction := Input.get_axis("left", "right")

	if knockback_timer > 0.0:
		direction = 0.0

	if direction:
		player.velocity.x = direction * SPEED
		facing_direction = direction
		if state_machine.current_state == state_machine.State.IDLE:
			state_machine.current_state = state_machine.State.RUN
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, SPEED * GROUND_FRICTION * delta)
		if state_machine.current_state == state_machine.State.RUN:
			state_machine.current_state = state_machine.State.IDLE


func apply_gravity(delta: float) -> void:
	player.velocity.y += player.get_gravity().y * delta


func apply_variable_jump_cut() -> void:
	if player.velocity.y < 0 and Input.is_action_just_released("up"):
		player.velocity.y *= JUMP_CUT_MULTIPLIER


func apply_wall_slide_friction() -> void:
	var direction_into_wall := Input.get_axis("left", "right")
	if direction_into_wall != 0 and sign(direction_into_wall) == -sign(last_wall_normal.x):
		player.velocity.y = min(player.velocity.y, WALL_SLIDE_MAX_FALL_SPEED)


func try_buffered_jumps() -> void:
	if jump_buffer_timer <= 0.0:
		return

	if player.unlocked_abilities.get("wall_jump", false) and wall_coyote_timer > 0.0:
		perform_wall_jump()
	elif coyote_timer > 0.0:
		perform_jump()
	elif player.unlocked_abilities.get("double_jump", false) and not double_jump_used:
		perform_double_jump()


func perform_jump() -> void:
	player.velocity.y = JUMP_VELOCITY
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	state_machine.current_state = state_machine.State.AIR

	animated_sprite.scale = Vector2(4, 4)

	var size_tween = create_tween()
	size_tween.tween_property(animated_sprite, "scale", Vector2(3.8, 4.2), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	size_tween.tween_property(animated_sprite, "scale", Vector2(4, 4), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	play_jump_dust()


func play_jump_dust() -> void:
	var jump_dust_scene = preload("res://Scenes/jump_dust.tscn")
	var jump_dust_instance = jump_dust_scene.instantiate()
	
	# Position at player's feet
	jump_dust_instance.position = player.position - Vector2(0, 2)
	jump_dust_instance.scale = Vector2(2, 2)
	
	# Add to the world (not the player) so it stays at ground level
	player.get_parent().add_child(jump_dust_instance)
	
	# Play animation and auto-remove when done
	jump_dust_instance.play("jump_dust")
	jump_dust_instance.animation_finished.connect(func(): jump_dust_instance.queue_free())


func perform_double_jump() -> void:
	player.velocity.y = JUMP_VELOCITY
	double_jump_used = true
	jump_buffer_timer = 0.0
	state_machine.current_state = state_machine.State.AIR
	
	play_jump_dust()


func perform_wall_jump() -> void:
	player.velocity.x = last_wall_normal.x * WALL_JUMP_PUSH
	player.velocity.y = WALL_JUMP_UP
	jump_buffer_timer = 0.0
	wall_coyote_timer = 0.0
	state_machine.current_state = state_machine.State.AIR
	
	play_jump_dust()


func check_dash_input() -> bool:
	return player.unlocked_abilities.get("dash", false) and Input.is_action_just_pressed("dash")


func start_dash() -> void:
	var dash_dir = facing_direction
	if player.velocity.x != 0:
		dash_dir = sign(player.velocity.x)
	player.velocity.x = SPEED * dash_dir * DASH_SPEED_MULTIPLIER
	dash_timer = 0.2
	state_machine.current_state = state_machine.State.DASH


func tick_dash(delta: float) -> void:
	dash_timer -= delta


func finish_dash_if_expired() -> void:
	if dash_timer <= 0.0:
		state_machine.current_state = state_machine.State.IDLE if player.is_on_floor() else state_machine.State.AIR
		player.velocity.x = move_toward(player.velocity.x, 0, SPEED * DASH_FRICTION)
