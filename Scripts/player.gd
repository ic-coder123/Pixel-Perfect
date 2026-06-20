extends CharacterBody2D

var unlocked_abilities = {}
var health := 5
var invulnerability_timer := 0.0

const INVULNERABILITY_DURATION := 1.5

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


func respawn() -> void:
	Main.respawn_player(self)


func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if invulnerability_timer > 0:
		return
	health -= amount
	took_damage.emit()
	invulnerability_timer = INVULNERABILITY_DURATION

	var knock_dir = sign(global_position.x - source_position.x) if source_position != Vector2.ZERO else -state_machine.movement.facing_direction
	if knock_dir == 0:
		knock_dir = -state_machine.movement.facing_direction

	state_machine.on_damaged(Vector2(knock_dir * 500, -350))

	print("Player took damage! Health: ", health)

	var flash_tween = create_tween()
	flash_tween.tween_property(animated_sprite, "modulate:a", 0.5, 0.1)
	flash_tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.1)
	flash_tween.set_loops(5)

	if health <= 0:
		respawn()


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
