extends Area2D

# when the player enters this checkpoint area we register its position

func _ready():
    # ensure the area monitors bodies
    connect("body_entered",Callable(self,"_on_body_entered"))

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        body.health = 100 # restore health on checkpoint
        # record the global position of this checkpoint
        Main.set_checkpoint(global_position)

        if Main.has_method("respawn_all_enemies"):
            Main.respawn_all_enemies()
            print("Checkpoint reached and enemies respawned via Main.")
        
