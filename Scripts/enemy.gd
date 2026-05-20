extends CharacterBody2D
@onready var hitbox: Area2D = $Hitbox
@onready var edge_detector: RayCast2D = $edge_detector
const SPEED = 100.0
const DETECTION_RADIUS = 200.0
var direction := -1
var health := 50



var is_chasing: bool = false

func _ready() -> void:
	add_to_group("enemy")
	# Register spawn data so Main can recreate this node after it is queue_free'd
	if Main.has_method("register_enemy_spawn"):
		Main.register_enemy_spawn(scene_file_path, global_position)


func _physics_process(delta: float) -> void:

	# Add gravity
	if not is_on_floor():
		velocity.y += 980.0 * delta

	# Player detection
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		var distance_to_player = global_position.distance_to(player.global_position)
		is_chasing = distance_to_player < DETECTION_RADIUS
	else:
		is_chasing = false
		
	if is_chasing:
		# Chase logic: move towards the player
		var direction_to_player = sign((player.global_position - global_position).x)
		if direction_to_player:
			direction = direction_to_player
			scale.x = abs(scale.x) * direction
	else:
		# Patrol logic: turn at edges
		if is_on_floor() and not edge_detector.is_colliding():
			print("Turning around at edge")
			direction *= -1

			edge_detector.target_position.x = abs(edge_detector.target_position.x) * direction
		
	# Move in current direction
	velocity.x = direction * SPEED

	move_and_slide()


func take_damage(amount: int) -> void:
	health -= amount
	print("Enemy took damage! Health: ", health)
	if health <= 0:
		queue_free()

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		print("Player hit!")
		if body.has_method("take_damage"):
			body.take_damage(1, global_position)
