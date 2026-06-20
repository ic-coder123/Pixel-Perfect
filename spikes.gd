extends Node2D
var health := 10
var amount := 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func take_damage() -> void:
	health -= amount
	print("Spikes took damage! Health: ", health)
	if health <= 0:
		queue_free()
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		print("Player hit by spike!")
		if body.has_method("take_damage"):
			body.take_damage(1)