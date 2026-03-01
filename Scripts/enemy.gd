extends CharacterBody2D

@onready var edge_detector: RayCast2D = $edge_detector
const SPEED = 100.0
const DETECTION_RADIUS = 200.0
var direction := -1
var health := 20

func _ready() -> void:
	add_to_group("enemy")

func _physics_process(delta: float) -> void:

	# Update detector to face movement direction
	edge_detector.position.x = abs(edge_detector.position.x) * direction

	if is_on_floor() and not edge_detector.is_colliding():
		direction *= -1
		edge_detector.position.x = abs(edge_detector.position.x) * direction

	var player = get_tree().get_first_node_in_group("player")
	var is_chasing := false

	if player and global_position.distance_to(player.global_position) < DETECTION_RADIUS:
		is_chasing = true
		var dir_to_player = sign(player.global_position.x - global_position.x)
		if dir_to_player != 0:
			direction = dir_to_player

	# Move in current direction
	velocity.x = direction * SPEED

	move_and_slide()
	
	if not is_chasing and is_on_wall():
		direction *= -1

func take_damage(amount: int) -> void:
	health -= amount
	print("Enemy took damage! Health: ", health)
	if health <= 0:
		queue_free()

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		print("Player hit!")
		if body.has_method("respawn"):
			body.respawn()
