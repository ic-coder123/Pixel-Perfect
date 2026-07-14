extends "res://Scripts/enemy.gd"

# Flying enemy specific properties
@export var SPEED := 150.0
@export var DETECTION_RADIUS := 500.0
@export var EXPANDED_RADIUS_MULTIPLIER := 2.0
@export var SHOOT_COOLDOWN := 1.5
@export var PROJECTILE_SPEED := 300.0
@export var TRACKING_SPEED := 200.0
@export var PATROL_RADIUS := 200.0
@export var PATROL_SPEED := 80.0

var player_detected := false
var player_position := Vector2.ZERO
var patrol_center := Vector2.ZERO
var patrol_angle := 0.0
var patrol_direction := 1.0
var _detection_collision_shape: CollisionShape2D
var _base_detection_radius := 0.0
var _player_node: Node = null

func _ready() -> void:
	super()  # Call base class _ready() to initialize nodes and add to group

	# Connect signals
	if detection_area:
		detection_area.connect("body_entered", Callable(self, "_on_detection_area_body_entered"))
		detection_area.connect("body_exited", Callable(self, "_on_detection_area_body_exited"))

		# Store reference to the collision shape and read its current radius as the base
		_detection_collision_shape = detection_area.get_node_or_null("CollisionShape2D")
		if _detection_collision_shape and _detection_collision_shape.shape is CircleShape2D:
			_base_detection_radius = _detection_collision_shape.shape.radius

	if shoot_timer:
		shoot_timer.wait_time = SHOOT_COOLDOWN
		shoot_timer.one_shot = true
		shoot_timer.timeout.connect(_on_shoot_timer_timeout)

	# Initialize patrol behavior
	patrol_center = global_position
	patrol_angle = randf_range(0, 2 * PI)

func _handle_movement(delta: float) -> void:
	# Flying enemies don't use gravity
	velocity.y = 0

	if player_detected and _player_node:
		# Continuously update player position so we chase the current location
		player_position = _player_node.global_position
		var direction_to_player = (player_position - global_position).normalized()
		velocity = direction_to_player * TRACKING_SPEED
	else:
		# Circular patrol behavior when no player detected
		patrol_angle += delta * patrol_direction * 0.5
		var patrol_offset = Vector2(cos(patrol_angle), sin(patrol_angle)) * PATROL_RADIUS
		var target_position = patrol_center + patrol_offset

		# Move towards patrol target
		var direction_to_target = (target_position - global_position).normalized()
		velocity = direction_to_target * PATROL_SPEED

		# Occasionally change patrol direction
		if randf() < 0.01:  # 1% chance per frame
			patrol_direction *= -1

func _handle_detection(delta: float) -> void:
	# Detection is handled by the area signals
	pass

func _on_detection_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_detected = true
		_player_node = body
		player_position = body.global_position
		_on_player_detected()

		# Expand detection radius so the player can't easily run away
		if _detection_collision_shape and _detection_collision_shape.shape is CircleShape2D:
			_detection_collision_shape.shape.radius = _base_detection_radius * EXPANDED_RADIUS_MULTIPLIER

		# Start shooting if timer is stopped (not already running)
		if shoot_timer and shoot_timer.is_stopped():
			shoot_timer.start()

func _on_detection_area_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_detected = false
		_player_node = null
		player_position = Vector2.ZERO
		_on_player_lost()

		# Shrink detection radius back to base size
		if _detection_collision_shape and _detection_collision_shape.shape is CircleShape2D:
			_detection_collision_shape.shape.radius = _base_detection_radius

func _on_shoot_timer_timeout() -> void:
	_shoot_projectile()

func _shoot_projectile() -> void:
	if not projectile_spawn or not player_detected:
		return

	# Create projectile instance
	var projectile_scene = load("res://Scenes/enemy_projectile.tscn")
	if projectile_scene:
		var projectile = projectile_scene.instantiate()
		get_parent().add_child(projectile)

		# Position and aim projectile
		projectile.global_position = projectile_spawn.global_position
		var direction = (player_position - projectile_spawn.global_position).normalized()
		projectile.velocity = direction * PROJECTILE_SPEED

		# Restart shoot timer
		if shoot_timer:
			shoot_timer.start()
