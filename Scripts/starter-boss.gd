extends CharacterBody2D

#---Variables---
@export var health := 200
@export var DAMAGE_DEALT := 10


# --- Constants ---
@export var LUNGE_SPEED := 600.0
@export var LUNGE_DURATION := 0.5
@export var ATTACK_COOLDOWN := 2.0
@export var STUN_DURATION := 1.0

# --- Nodes ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player_detection_cast: RayCast2D = $RayCast2D

# --- State Machine ---
enum State {IDLE, LUNGING, COOLDOWN, STUNNED}
var current_state := State.IDLE

# --- State Variables ---
var lunge_timer := 0.0
var cooldown_timer := 0.0
var lunge_direction := Vector2.ZERO
var stun_timer := 0.0

# --- Physics ---
func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			process_idle_state()
		State.LUNGING:
			process_lunging_state(delta)
		State.COOLDOWN:
			process_cooldown_state(delta)
	
	move_and_slide()

# This is the function your player is looking for!
func deal_damage_to_player(player: Node) -> void:
	if player.has_method("take_damage"):
		player.take_damage(DAMAGE_DEALT)
	elif player.is_in_group("player"):
		print("Warning: Detected a node in 'player' group without 'take_damage' method!")


func take_damage(amount: int) -> void:
	health -= amount
	
	# 1. Start the Stun
	trigger_stun()
	
	# 3. Add 'Juice' (Flash white, play sound, etc.)
	flash_white()

func trigger_stun() -> void:
	if current_state == State.STUNNED:
		return
		
	current_state = State.STUNNED
	stun_timer = STUN_DURATION
	velocity = Vector2.ZERO # Stop dead in tracks
	

	print("Boss took damage and is now stunned!")

func flash_white() -> void:
	var original_modulate = animated_sprite.modulate
	var flash_tween = create_tween()
	flash_tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1), 0.1)
	flash_tween.tween_property(animated_sprite, "modulate", original_modulate, 0.1).set_delay(0.1)


# --- State Functions ---


func process_idle_state() -> void:
	velocity = Vector2.ZERO
	
	if player_detection_cast.is_colliding():
		var target = player_detection_cast.get_collider()
		
		# This is the line that's likely failing. 
		# We check if target exists, then check the group.
		if target and target.is_in_group("player"):
			print("Found the player! Lunging now.")
			start_lunge(target.global_position)
		else:
			# This helps you debug! If it hits a wall, it will tell you.
			# print("RayCast hit something else: ", target.name)
			pass

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
