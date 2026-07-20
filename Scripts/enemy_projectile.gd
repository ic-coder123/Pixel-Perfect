extends Area2D

@export var velocity: Vector2 = Vector2.ZERO
@export var damage :=1
@export var lifetime := 3.0

var time_alive := 0.0

func _ready() -> void:
	# Connect the body_entered signal if not already connected in the editor
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()

	# Move projectile
	global_position += velocity * delta

func _on_body_entered(body: Node) -> void:
	# Deal damage to player
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		queue_free()
