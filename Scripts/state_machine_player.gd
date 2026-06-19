class_name StateMachinePlayer
extends Node

const MovementPlayerComponentScript = preload("res://Scenes/movement_player_component.gd")

enum State { IDLE, RUN, AIR, WALL_SLIDE, DASH, ATTACK }
var current_state = State.IDLE

var attack_timer := 0.0
var _was_attack_pressed := false

var movement

@onready var player: CharacterBody2D = get_parent()
@onready var animated_sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
@onready var sword_area: Area2D = player.get_node("Sword")


func _ready() -> void:
	movement = get_node_or_null("MovementPlayerComponent")
	if movement == null:
		movement = MovementPlayerComponentScript.new()
		movement.name = "MovementPlayerComponent"
		add_child(movement)
	movement.setup(player, self, animated_sprite)


func _physics_process(delta: float) -> void:
	update_timers_and_input(delta)
	movement.update_landing()

	match current_state:
		State.IDLE, State.RUN:
			process_ground_state(delta)
			animated_sprite.play("IDLE")
			animated_sprite.flip_h = movement.facing_direction < 0

		State.AIR:
			process_air_state(delta)

		State.WALL_SLIDE:
			process_wall_slide_state(delta)

		State.DASH:
			process_dash_state(delta)
			animated_sprite.play("DASH")
			animated_sprite.flip_h = movement.facing_direction < 0

		State.ATTACK:
			process_attack_state(delta)

	player.move_and_slide()
	handle_state_transitions()


func on_damaged(knockback_velocity: Vector2) -> void:
	interrupt_combat()
	movement.apply_knockback(knockback_velocity)
	current_state = State.AIR


func interrupt_combat() -> void:
	sword_area.set_deferred("monitoring", false)
	sword_area.visible = false
	movement.dash_timer = 0.0


func perform_pogo_bounce() -> void:
	movement.apply_pogo_bounce()
	current_state = State.AIR
	sword_area.set_deferred("monitoring", false)
	sword_area.visible = false


func update_timers_and_input(delta: float) -> void:
	movement.update_timers(delta)

	var attack_pressed := Input.is_action_pressed("attack")
	if attack_pressed and not _was_attack_pressed:
		if current_state != State.ATTACK and current_state != State.DASH and current_state != State.WALL_SLIDE:
			perform_attack()
	_was_attack_pressed = attack_pressed


func process_ground_state(delta: float) -> void:
	movement.handle_horizontal_movement(delta)

	if movement.jump_buffer_timer > 0.0:
		movement.perform_jump()

	if movement.check_dash_input():
		movement.start_dash()


func process_air_state(delta: float) -> void:
	movement.apply_gravity(delta)
	movement.handle_horizontal_movement(delta)
	movement.apply_variable_jump_cut()
	movement.try_buffered_jumps()

	if movement.check_dash_input():
		movement.start_dash()


func process_wall_slide_state(delta: float) -> void:
	movement.apply_gravity(delta)
	movement.apply_wall_slide_friction()
	movement.handle_horizontal_movement(delta)

	if movement.jump_buffer_timer > 0.0:
		movement.perform_wall_jump()


func process_dash_state(delta: float) -> void:
	movement.tick_dash(delta)


func process_attack_state(delta: float) -> void:
	if not player.is_on_floor():
		movement.apply_gravity(delta)
	attack_timer -= delta
	movement.handle_horizontal_movement(delta)


func handle_state_transitions() -> void:
	if not current_state == State.DASH:
		animated_sprite.flip_h = movement.facing_direction < 0

	match current_state:
		State.IDLE, State.RUN:
			if not player.is_on_floor():
				current_state = State.AIR
		State.AIR:
			if player.is_on_floor():
				current_state = State.IDLE
			elif player.unlocked_abilities.get("wall_jump", false) and player.is_on_wall_only():
				if abs(player.get_wall_normal().x) > 0.6:
					current_state = State.WALL_SLIDE
		State.WALL_SLIDE:
			if player.is_on_floor():
				current_state = State.IDLE
			elif not player.is_on_wall():
				current_state = State.AIR
		State.DASH:
			movement.finish_dash_if_expired()
		State.ATTACK:
			if attack_timer <= 0.0:
				sword_area.set_deferred("monitoring", false)
				sword_area.visible = false
				current_state = State.IDLE if player.is_on_floor() else State.AIR


func perform_attack() -> void:
	current_state = State.ATTACK
	attack_timer = 0.3
	if player.is_on_floor():
		player.velocity = Vector2.ZERO
	animated_sprite.play("ATTACK")

	sword_area.rotation = 0
	sword_area.scale.x = 1.0
	sword_area.visible = true
	sword_area.set_deferred("monitoring", true)

	if Input.is_action_pressed("down"):
		sword_area.rotation = PI / 2
	elif Input.is_action_pressed("up"):
		sword_area.rotation = -PI / 2
	else:
		sword_area.scale.x = movement.facing_direction
