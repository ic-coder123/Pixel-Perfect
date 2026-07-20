extends CharacterBody2D
var unlocked_abilities
@export var health := 5
@export var max_health := 5
@export var mana := 0
var invulnerability_timer := 0.0

@export var INVULNERABILITY_DURATION := 1.5
@export var KNOCKBACK_HORIZONTAL := 500
@export var KNOCKBACK_VERTICAL := -350
@export var FLASH_LOOP_COUNT := 5

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


func _on_sword_hit(body: Node) -> void:
	state_machine.combat.handle_sword_hit(body)
	mana += 1

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

	if Input.is_action_just_pressed("heal") and mana >= 2 and health < max_health:
		health += 1
		mana -= 2
		print("Healed! Health: ", health, " Mana: ", mana)
