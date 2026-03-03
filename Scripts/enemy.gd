extends CharacterBody2D
@onready var hitbox: Area2D = $Hitbox
@onready var edge_detector: RayCast2D = $edge_detector
const SPEED = 100.0
const DETECTION_RADIUS = 200.0
var direction := -1
var health := 20

# If true, the enemy is currently pursuing the player (set by your detection logic).
# This was referenced below but never declared, causing a scope error.
var is_chasing: bool = false

func _ready() -> void:
	add_to_group("enemy")

func _physics_process(delta: float) -> void:

	# Add gravity
	if not is_on_floor():
		velocity.y += 980.0 * delta

	var player = get_tree().get_first_node_in_group("player")
	is_chasing = false
	if player and global_position.distance_to(player.global_position) < DETECTION_RADIUS:
		is_chasing = true
		var dir_to_player = sign(player.global_position.x - global_position.x)
		if dir_to_player != 0:
			direction = dir_to_player

	# Update detector to face movement direction
	edge_detector.position.x = abs(edge_detector.position.x) * direction
	edge_detector.force_raycast_update()

	if hitbox.get_overlapping_bodies().size() > 0:
		for body in hitbox.get_overlapping_bodies():
			if body.is_in_group("player"):
				print("Player hit!")
				if body.has_method("take_damage"):
					body.take_damage(10)

	var current_speed = SPEED
	if is_on_floor() and not edge_detector.is_colliding():
		if is_chasing:
			current_speed = 0
		else:
			direction *= -1
			edge_detector.position.x = abs(edge_detector.position.x) * direction
	
	# Move in current direction
	velocity.x = direction * current_speed

	move_and_slide()

	# Flip direction when hitting a wall while patrolling.
	
	if not is_chasing and is_on_wall():
		direction *= -1

		edge_detector.position.x = abs(edge_detector.position.x) * direction

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
