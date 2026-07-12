extends CharacterBody2D

# Base enemy class - all enemies should extend this
@onready var hitbox: Area2D = $Hitbox
@onready var sprite: Sprite2D = $Icon

# Common properties for all enemies
@export var health := 50
@export var DAMAGE_DEALT := 1

# Optional nodes (may not exist in all enemy types)
var dash_initiater: RayCast2D
var wall_detector: RayCast2D
var edge_detector: RayCast2D
var detection_area: Area2D
var shoot_timer: Timer
var projectile_spawn: Marker2D

func _ready() -> void:
	add_to_group("enemy")
	# Register spawn data so Main can recreate this node after it is queue_free'd
	if Main.has_method("register_enemy_spawn"):
		Main.register_enemy_spawn(scene_file_path, global_position)

	# Initialize optional nodes (use get_node_or_null to avoid errors when nodes don't exist)
	dash_initiater = get_node_or_null("dash_initiater")
	wall_detector = get_node_or_null("wall_detector")
	edge_detector = get_node_or_null("edge_detector")
	detection_area = get_node_or_null("DetectionArea")
	shoot_timer = get_node_or_null("ShootTimer")
	projectile_spawn = get_node_or_null("Marker2D")

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_detection(delta)
	move_and_slide()

# Virtual methods - subclasses can override these
func _handle_movement(delta: float) -> void:
	pass  # Base implementation does nothing

func _handle_detection(delta: float) -> void:
	pass  # Base implementation does nothing

func _on_player_detected() -> void:
	pass  # Hook for when player is detected

func _on_player_lost() -> void:
	pass  # Hook for when player is no longer detected

func take_damage(amount: int) -> void:
	health -= amount
	print("Enemy took damage! Health: ", health)

	# Flash red effect
	var original_modulate = sprite.modulate
	sprite.modulate = Color.RED

	var tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.2)

	if health <= 0:
		queue_free()

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		print("Player hit!")
		if body.has_method("take_damage"):
			body.take_damage(DAMAGE_DEALT, global_position)