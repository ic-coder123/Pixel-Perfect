extends Area2D

# when the player enters the death volume we send them back to the last checkpoint

func _ready():
    connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        # if the player has a respawn method, call it, otherwise teleport directly
        if body.has_method("respawn"):
            body.respawn()
        else:
            body.global_position = Main.get_checkpoint()
            if body.has_variable("velocity"):
                body.velocity = Vector2.ZERO
