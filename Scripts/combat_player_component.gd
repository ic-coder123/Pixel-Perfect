class_name CombatPlayerComponent
extends Node

const ATTACK_DURATION := 0.3
const SWORD_DAMAGE := 10

var attack_timer := 0.0
var _was_attack_pressed := false

var player: CharacterBody2D
var state_machine: Node
var movement: Node
var animated_sprite: AnimatedSprite2D
var sword_area: Area2D


func setup(p: CharacterBody2D, sm: Node, movement_comp: Node, sprite: AnimatedSprite2D, sword: Area2D) -> void:
	player = p
	state_machine = sm
	movement = movement_comp
	animated_sprite = sprite
	sword_area = sword
	sword_area.monitoring = false
	sword_area.visible = false


func update_attack_input() -> void:
	var attack_pressed := Input.is_action_pressed("attack")
	if attack_pressed and not _was_attack_pressed:
		if can_attack():
			perform_attack()
	_was_attack_pressed = attack_pressed


func can_attack() -> bool:
	return (
		state_machine.current_state != state_machine.State.ATTACK
		and state_machine.current_state != state_machine.State.DASH
		and state_machine.current_state != state_machine.State.WALL_SLIDE
	)


func perform_attack() -> void:
	state_machine.current_state = state_machine.State.ATTACK
	attack_timer = ATTACK_DURATION
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


func tick_attack(delta: float) -> void:
	attack_timer -= delta


func finish_attack_if_expired() -> void:
	if attack_timer <= 0.0:
		hide_sword()
		state_machine.current_state = state_machine.State.IDLE if player.is_on_floor() else state_machine.State.AIR


func hide_sword() -> void:
	sword_area.set_deferred("monitoring", false)
	sword_area.visible = false


func interrupt() -> void:
	hide_sword()
	attack_timer = 0.0


func handle_pogo_bounce() -> void:
	movement.apply_pogo_bounce()
	state_machine.current_state = state_machine.State.AIR
	hide_sword()


func is_down_attack() -> bool:
	return (
		state_machine.current_state == state_machine.State.ATTACK
		and is_equal_approx(sword_area.rotation, PI / 2)
	)


func handle_sword_hit(body: Node) -> void:
	if body == player:
		return

	if is_down_attack():
		if body.is_in_group("enemy") or body.is_in_group("hazard") or body.has_method("take_damage"):
			handle_pogo_bounce()

	if body.has_method("take_damage"):
		body.take_damage(SWORD_DAMAGE)
	elif body.is_in_group("enemy"):
		body.queue_free()
