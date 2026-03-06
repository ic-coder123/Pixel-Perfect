extends CharacterBody2D

# --- Constants ---
const LUNGE_SPEED := 600.0
const LUNGE_DURATION := 0.5
const ATTACK_COOLDOWN := 2.0

# --- Nodes ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player_detection_cast: RayCast2D = $RayCast2D

# --- State Machine ---
enum State { IDLE, LUNGING, COOLDOWN }
var current_state := State.IDLE

# --- State Variables ---
var lunge_timer := 0.0
var cooldown_timer := 0.0
var lunge_direction := Vector2.ZERO

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			process_idle_state()
		State.LUNGING:
			process_lunging_state(delta)
		State.COOLDOWN:
			process_cooldown_state(delta)
	
	move_and_slide()





func process_idle_state() -> void:
	velocity = Vector2.ZERO
	# animated_sprite.play("idle") # Assuming you have an "idle" animation

	if player_detection_cast.is_colliding():
		print("Colliding with" + str(player_detection_cast.get_collider()))
		start_lunge(player_detection_cast.get_collider().global_position)

func process_lunging_state(delta: float) -> void:
	# animated_sprite.play("lunge") # Assuming you have a "lunge" animation
	velocity = lunge_direction * LUNGE_SPEED
	
	lunge_timer -= delta
	if lunge_timer <= 0.0:
		current_state = State.COOLDOWN
		cooldown_timer = ATTACK_COOLDOWN

func process_cooldown_state(delta: float) -> void:
	velocity = Vector2.ZERO
	# animated_sprite.play("idle")
	
	cooldown_timer -= delta
	if cooldown_timer <= 0.0:
		current_state = State.IDLE

func start_lunge(player_position: Vector2) -> void:
	print("Player detected! Lunging.")
	lunge_direction = (player_position - global_position).normalized()
	animated_sprite.flip_h = lunge_direction.x < 0
	lunge_timer = LUNGE_DURATION
	current_state = State.LUNGING
