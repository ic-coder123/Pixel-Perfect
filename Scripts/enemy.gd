extends CharacterBody2D
@onready var hitbox: Area2D = $Hitbox
@onready var edge_detector: RayCast2D = $edge_detector
@onready var dash_initiater: RayCast2D = $dash_initiater

const SPEED = 100.0
const DASH_SPEED = 400.0
var direction := -1
var health := 50

func _ready() -> void:
	add_to_group("enemy")
	# Register spawn data so Main can recreate this node after it is queue_free'd
	if Main.has_method("register_enemy_spawn"):
		Main.register_enemy_spawn(scene_file_path, global_position)


func _physics_process(delta: float) -> void:

	# Add gravity
	if not is_on_floor():
		velocity.y += 980.0 * delta

	var current_speed = SPEED

	# Dash logic: speed up if the player is detected by the dash_initiater
	if dash_initiater.is_colliding():
		var collider = dash_initiater.get_collider()
		if collider and collider.is_in_group("player"):
			current_speed = DASH_SPEED

	# Patrol logic: turn at edges
	if is_on_floor() and not edge_detector.is_colliding():
		print("Turning around at edge")
		direction *= -1
		edge_detector.target_position.x = abs(edge_detector.target_position.x) * direction
		dash_initiater.target_position.x = abs(dash_initiater.target_position.x) * direction

	# Move in current direction
	velocity.x = direction * current_speed

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
