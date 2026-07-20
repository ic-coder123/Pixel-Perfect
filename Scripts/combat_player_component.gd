class_name CombatPlayerComponent
extends Node

@export var ATTACK_DURATION := 0.5
@export var SWORD_DAMAGE := 10

var attack_timer := 0.0
var _was_attack_pressed := false

var player: CharacterBody2D
var state_machine: StateMachinePlayer
var movement: MovementPlayerComponent
var animated_sprite: AnimatedSprite2D
var sword_area: Area2D
var sword_animated_sprite: AnimatedSprite2D


func setup(p: CharacterBody2D, sm: Node, movement_comp: Node, sprite: AnimatedSprite2D, sword: Area2D, sword_anim_sprite: AnimatedSprite2D) -> void:
	player = p
	state_machine = sm
	movement = movement_comp
	animated_sprite = sprite
	sword_area = sword
	sword_animated_sprite = sword_anim_sprite
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


	sword_area.rotation = 0
	sword_area.scale.x = 1.0
	sword_area.visible = true
	sword_area.set_deferred("monitoring", true)
	sword_animated_sprite.play()
	sword_animated_sprite.frame = 0

	if Input.is_action_pressed("down"):
		sword_area.rotation = PI / 2
	elif Input.is_action_pressed("up"):
		sword_area.rotation = - PI / 2
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
	sword_animated_sprite.stop()


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
	print("Sword hit something: ", body.name, " groups: ", body.get_groups())
	if body == player:
		return

	var target = body

	# Debugging print statement
	print("Attempting to shake the camera and apply hit stop.")

	# Screen shake on hit
	var camera = player.get_node_or_null("Camera2D")
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.6)

	# Hit-stop: brief freeze frame for impact feel
	if target.is_in_group("enemy") or target.is_in_group("hazard") or target.has_method("take_damage"):
		_hit_stop(0.12)

	if is_down_attack():
		if target.is_in_group("enemy") or target.is_in_group("hazard") or target.has_method("take_damage"):
			handle_pogo_bounce()

	if target.has_method("take_damage"):
		target.take_damage(SWORD_DAMAGE)
		# Debugging print statement
		print("Damage dealt to target: ", target.name, " Damage amount: ", SWORD_DAMAGE)


func _hit_stop(duration: float) -> void:
	Engine.time_scale = 0.0
	await get_tree().create_timer(duration, true, true, true).timeout
	Engine.time_scale = 1.0
