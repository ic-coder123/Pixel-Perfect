class_name StateMachinePlayer
extends Node

enum State {IDLE, RUN, AIR, WALL_SLIDE, DASH, ATTACK, LANDED}
var current_state = State.IDLE


@onready var player: CharacterBody2D = get_parent()
@onready var animated_sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
@onready var movement: MovementPlayerComponent = $MovementPlayerComponent
@onready var combat: CombatPlayerComponent = $CombatPlayerComponent


func _ready() -> void:
	movement.setup(player, self, animated_sprite)
	combat.setup(player, self, movement, animated_sprite, player.get_node("Sword"), player.get_node("Sword/SwordSprite2D"))


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

		State.LANDED:
			pass
	player.move_and_slide()
	handle_state_transitions()


func on_damaged(knockback_velocity: Vector2) -> void:
	combat.interrupt()
	movement.dash_timer = 0.0
	movement.apply_knockback(knockback_velocity)
	current_state = State.AIR


func update_timers_and_input(delta: float) -> void:
	movement.update_timers(delta)
	combat.update_attack_input()


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
	if not player.is_on_floor():
		current_state = State.AIR
		

func process_attack_state(delta: float) -> void:
	if not player.is_on_floor():
		movement.apply_gravity(delta)
	combat.tick_attack(delta)
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
			combat.finish_attack_if_expired()
