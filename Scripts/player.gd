extends CharacterBody2D
var unlocked_abilities
@export var health := 5
@export var max_health := 5
@export var mana := 0
@export var max_mana := 5
var invulnerability_timer := 0.0

@export var INVULNERABILITY_DURATION := 1.5
@export var KNOCKBACK_HORIZONTAL := 500
@export var KNOCKBACK_VERTICAL := -350
@export var FLASH_LOOP_COUNT := 5

## Healing state variables
@export var HEAL_COMPLETE_TIME := 4.0
@export_range(0.0, 1.0) var HEAL_COMMIT_PERCENT := 0.75
@export var HEAL_MANA_COST := 2
var heal_timer := 0.0
var heal_mana_consumed := false
var heal_start_mana := 0
var heal_start_health := 0

## Smooth display values for UI bars
var display_mana: float = 0.0
var display_health: float = 5.0
const DISPLAY_LERP_SPEED := 15.0

signal took_damage

@onready var keybinder: Control = $Control
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var actionable_finder: Area2D = $actionable_finder
@onready var state_machine = $StateMachine


func _ready() -> void:
	unlocked_abilities = Main.unlocked_abilities
	if not is_in_group("player"):
		add_to_group("player")
	keybinder.visible = false
	display_mana = float(mana)
	display_health = float(health)


func _on_sword_hit(body: Node) -> void:
	state_machine.combat.handle_sword_hit(body)
	mana = min(mana + 1, max_mana)

func respawn() -> void:
	Main.respawn_player(self)


func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if invulnerability_timer > 0:
		return
	health -= amount
	took_damage.emit()
	invulnerability_timer = INVULNERABILITY_DURATION

	# Screen shake on damage
	var camera = get_node_or_null("Camera2D")
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.8)

	# Hit stop on player damage
	_hit_stop(0.1)

	var knock_dir = sign(global_position.x - source_position.x) if source_position != Vector2.ZERO else -state_machine.movement.facing_direction
	if knock_dir == 0:
		knock_dir = - state_machine.movement.facing_direction

	state_machine.on_damaged(Vector2(knock_dir * KNOCKBACK_HORIZONTAL, KNOCKBACK_VERTICAL))

	print("Player took damage! Health: ", health)

	var flash_tween = create_tween()
	flash_tween.tween_property(animated_sprite, "modulate:a", 0.5, 0.1)
	flash_tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.1)
	flash_tween.set_loops(FLASH_LOOP_COUNT)

	if health <= 0:
		respawn()


func _handle_heal_input(delta: float) -> void:
	if not is_instance_valid(state_machine):
		return
	
	var healing: bool = state_machine.current_state == state_machine.State.HEALING
	
	if healing:
		if Input.is_action_pressed("heal"):
			_tick_healing(delta)
		else:
			_cancel_healing()
	else:
		if Input.is_action_pressed("heal") and mana >= HEAL_MANA_COST and health < max_health:
			_start_healing()


func _start_healing() -> void:
	heal_timer = 0.0
	heal_mana_consumed = false
	heal_start_mana = mana
	heal_start_health = health
	state_machine.current_state = state_machine.State.HEALING


func _tick_healing(delta: float) -> void:
	heal_timer += delta
	
	if not heal_mana_consumed and heal_timer >= HEAL_COMPLETE_TIME * HEAL_COMMIT_PERCENT:
		heal_mana_consumed = true
		mana -= HEAL_MANA_COST
		print("Heal mana committed. Mana: ", mana)
	
	if heal_timer >= HEAL_COMPLETE_TIME:
		health += 1
		heal_timer -= HEAL_COMPLETE_TIME
		heal_mana_consumed = false
		heal_start_mana = mana
		heal_start_health = health
		print("Healed! Health: ", health, " Mana: ", mana)
		
		if mana < HEAL_MANA_COST or health >= max_health:
			state_machine.current_state = state_machine.State.IDLE


func _cancel_healing() -> void:
	if heal_mana_consumed:
		print("Heal cancelled after commit — mana lost, no health gained.")
	else:
		print("Heal cancelled before commit — nothing lost.")
	heal_timer = 0.0
	heal_mana_consumed = false
	state_machine.current_state = state_machine.State.IDLE


func _hit_stop(duration: float) -> void:
	Engine.time_scale = 0.0
	await get_tree().create_timer(duration, true, true, true).timeout
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	invulnerability_timer = max(invulnerability_timer - delta, 0.0)

	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
		var actionables = actionable_finder.get_overlapping_areas()
		if actionables.size() > 0:
			print("interacting")
			actionables[0].action()
			return

	if Input.is_action_just_pressed("ui_cancel"):
		keybinder.visible = !keybinder.visible
		if not keybinder.visible:
			var focused = get_viewport().gui_get_focus_owner()
			if focused:
				focused.release_focus()

	_handle_heal_input(delta)
	_update_display_values(delta)


func _update_display_values(delta: float) -> void:
	var target_display_mana: float
	var target_display_health: float
	
	if is_instance_valid(state_machine) and state_machine.current_state == state_machine.State.HEALING:
		var progress := float(min(heal_timer / HEAL_COMPLETE_TIME, 1.0))
		target_display_mana = float(heal_start_mana) - float(HEAL_MANA_COST) * progress
		target_display_health = float(heal_start_health) + 1.0 * progress
	else:
		target_display_mana = float(mana)
		target_display_health = float(health)
	
	display_mana = lerp(display_mana, target_display_mana, DISPLAY_LERP_SPEED * delta)
	display_health = lerp(display_health, target_display_health, DISPLAY_LERP_SPEED * delta)
