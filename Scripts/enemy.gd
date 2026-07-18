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
var projectile_scene = preload("res://Scenes/enemy_projectile.tscn")
var shoot_timer: Timer
var projectile_spawn: Marker2D

# Flag set immediately when health hits 0 (before queue_free defers deletion)
var _pending_deletion := false

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

func _safe_move_and_slide() -> void:
	# Prevent normalization errors from zero/NaN/Infinity velocity
	if not velocity.is_finite():
		velocity = Vector2.ZERO

	# Skip move_and_slide entirely when velocity is zero or the node
	# is pending deletion (e.g. killed mid-frame). Godot's internal
	# normalization will warn on zero vectors, and a dying node's
	# velocity can become stale/invalid on the next frame.
	if velocity.is_zero_approx() or _pending_deletion or is_queued_for_deletion():
		return

	move_and_slide()

func _physics_process(delta: float) -> void:
	# Skip all physics processing if this node is pending deletion
	# (e.g. killed this frame). Prevents Godot's move_and_slide()
	# from warning about zero/NaN velocity on a dying node.
	if _pending_deletion or is_queued_for_deletion():
		return

	_handle_movement(delta)
	_handle_detection(delta)
	_safe_move_and_slide()

# Virtual methods - subclasses can override these
func _handle_movement(delta: float) -> void:
	pass # Base implementation does nothing

func _handle_detection(delta: float) -> void:
	pass # Base implementation does nothing

func _on_player_detected() -> void:
	pass # Hook for when player is detected

func _on_player_lost() -> void:
	pass # Hook for when player is no longer detected

func take_damage(amount: int) -> void:
	health -= amount
	print("Enemy took damage! Health: ", health)

	# Flash red effect
	var original_modulate = sprite.modulate
	sprite.modulate = Color.RED

	var tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.2)

	if health <= 0:
		_pending_deletion = true
		_spawn_death_particles()
		queue_free()


func _spawn_death_particles() -> void:
	var particle_texture = preload("res://assets/generated/death_particle_frame_0.png")
	var parent_node = get_parent()
	for i in 8:
		var sprite_node = Sprite2D.new()
		sprite_node.texture = particle_texture
		sprite_node.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		sprite_node.scale = Vector2(randf_range(1.0, 2.5), randf_range(1.0, 2.5))
		sprite_node.modulate = Color(randf_range(0.8, 1.0), randf_range(0.3, 0.6), 0.0, 1.0)
		parent_node.add_child(sprite_node)

		var tween = parent_node.create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite_node, "position", sprite_node.position + Vector2(randf_range(-40, 40), randf_range(-60, -20)), 0.4).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite_node, "modulate:a", 0.0, 0.4)
		tween.tween_property(sprite_node, "scale", Vector2.ZERO, 0.4)
		tween.finished.connect(sprite_node.queue_free)

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		print("Player hit!")
		if body.has_method("take_damage"):
			body.take_damage(DAMAGE_DEALT, global_position)