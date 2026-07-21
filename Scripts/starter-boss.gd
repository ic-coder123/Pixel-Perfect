extends CharacterBody2D

#---Variables---
@export var health := 200
@export var DAMAGE_DEALT := 1


# --- Constants ---
@export var LUNGE_SPEED := 600.0
@export var LUNGE_DURATION := 0.5
@export var ATTACK_COOLDOWN := 2.0
@export var STUN_DURATION := 1.0

# --- Flight Constants ---
## Speed at which the boss flies/bounces around the arena
@export var FLY_SPEED := 220.0
## How often the boss picks a new flight direction (seconds)
@export var DIRECTION_CHANGE_INTERVAL := 2.5
## How often the boss checks if it should lunge at the player
@export var LUNGE_CHECK_INTERVAL := 1.0
## Amplitude of the vertical sine-bob while flying (for that "floating" feel)
@export var FLY_BOB_AMPLITUDE := 60.0
## Frequency of the vertical sine-bob
@export var FLY_BOB_FREQUENCY := 3.0

# --- Bounce/Recoil Constants ---
@export var RECOIL_SPEED := 400.0
@export var RECOIL_DURATION := 0.3
@export var BOUNCE_SPEED := 300.0
@export var BOUNCE_DURATION := 3.0

# --- Nodes ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player_detection_cast: RayCast2D = $RayCast2D


# --- State Machine ---
enum State {FLYING, LUNGING, COOLDOWN, STUNNED, BOUNCING}
var current_state := State.FLYING
var _last_player_position := Vector2.ZERO
var _has_seen_player := false
var _fly_bob_time := 0.0

# --- State Variables ---
var lunge_timer := 0.0
var cooldown_timer := 0.0
var lunge_direction := Vector2.ZERO
var stun_timer := 0.0

# --- Flight Variables ---
var fly_direction := Vector2.RIGHT
var direction_change_timer := 0.0
var lunge_check_timer := 0.0

# --- Bounce/Recoil Variables ---
var bounce_direction := Vector2.ZERO
var bounce_timer := 0.0
var recoil_timer := 0.0
var is_recoiling := false


func _ready() -> void:
	add_to_group("enemy")
	# Register spawn data so Main can recreate this node after checkpoint respawn
	if Main.has_method("register_enemy_spawn"):
		Main.register_enemy_spawn(scene_file_path, global_position)

	# Start flying right away with a random direction
	fly_direction = Vector2.from_angle(randf_range(0, TAU)).normalized()
	direction_change_timer = randf_range(0.5, DIRECTION_CHANGE_INTERVAL)


# --- Physics ---
func _physics_process(delta: float) -> void:
	match current_state:
		State.FLYING:
			process_flying_state(delta)
		State.LUNGING:
			process_lunging_state(delta)
		State.COOLDOWN:
			process_cooldown_state(delta)
		State.STUNNED:
			process_stunned_state(delta)
		State.BOUNCING:
			process_bouncing_state(delta)

	# Prevent normalization errors from zero/NaN velocity
	if not velocity.is_finite() or velocity.is_zero_approx():
		velocity = Vector2.ZERO

	move_and_slide()


# --- Hitbox Callback (connected from Hitbox Area2D's body_entered) ---
func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		deal_damage_to_player(body)
		start_bounce(body.global_position)


# This is the function your player is looking for!
func deal_damage_to_player(player: Node) -> void:
	if player.has_method("take_damage"):
		# Pass global_position so the player's knockback direction is away from the boss
		player.take_damage(DAMAGE_DEALT, global_position)
	elif player.is_in_group("player"):
		print("Warning: Detected a node in 'player' group without 'take_damage' method!")


func take_damage(amount: int) -> void:
	health -= amount

	# Start the Stun
	trigger_stun()

	# Add 'Juice' (Flash white, play sound, etc.)
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


# --- Bounce Logic ---
func start_bounce(player_position: Vector2) -> void:
	current_state = State.BOUNCING
	bounce_direction = (global_position - player_position).normalized()
	velocity = bounce_direction * RECOIL_SPEED
	is_recoiling = true
	recoil_timer = RECOIL_DURATION
	bounce_timer = BOUNCE_DURATION
	print("Boss recoiling from player hit!")


# --- Helper: Try to detect the player via dynamic raycast ---
## Points the existing RayCast2D node at the player each call and checks for LOS.
## Uses the node's collision mask so no layer mismatch issues.
func _check_player_detected() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return false

	var diff = player.global_position - global_position
	var distance = diff.length()
	
	# Broad-phase: too far away
	if distance > 800.0:
		player_detection_cast.enabled = false
		return false

	# Point the raycast at the player (the node handles collision mask setup)
	# to_local() converts to the raycast's local space, which is what target_position expects.
	player_detection_cast.target_position = player_detection_cast.to_local(player.global_position)
	player_detection_cast.enabled = true
	player_detection_cast.force_raycast_update()
	
	if not player_detection_cast.is_colliding():
		# Nothing in the way — LOS is clear!
		_last_player_position = player.global_position
		_has_seen_player = true
		print("DEBUG: Boss detected player — ray clear, distance: ", distance)
		return true
	
	var target = player_detection_cast.get_collider()
	if target and target.is_in_group("player"):
		# Ray hit the player directly
		_last_player_position = player.global_position
		_has_seen_player = true
		print("DEBUG: Boss detected player — direct hit, distance: ", distance)
		return true
	
	# Ray hit something else (wall/terrain)
	# Still remember player position if close enough
	if distance < 400.0:
		_last_player_position = player.global_position
		_has_seen_player = true
		print("DEBUG: Boss can't see player (obstacle), remembers position, distance: ", distance)
	
	return false


# --- Helper: Start a lunge toward a given position ---
func _start_lunge(target_position: Vector2) -> void:
	print("Boss lunging!")
	lunge_direction = (target_position - global_position).normalized()
	if lunge_direction.is_zero_approx():
		lunge_direction = Vector2.RIGHT
	animated_sprite.flip_h = lunge_direction.x < 0
	lunge_timer = LUNGE_DURATION
	current_state = State.LUNGING


# --- State Functions ---

func process_flying_state(delta: float) -> void:
	# --- Lunge opportunity check ---
	lunge_check_timer -= delta
	if lunge_check_timer <= 0.0:
		lunge_check_timer = LUNGE_CHECK_INTERVAL
		if _check_player_detected():
			# Random chance to lunge when player is detected
			if randf() < 0.4:  # 40% chance each check
				_start_lunge(_last_player_position)
				return # Skip movement this frame, lunge will set velocity

	# --- Direction change ---
	direction_change_timer -= delta
	if direction_change_timer <= 0.0:
		direction_change_timer = DIRECTION_CHANGE_INTERVAL
		# 50% chance to aim toward the player if we've seen them
		if _has_seen_player and randf() < 0.5:
			fly_direction = (_last_player_position - global_position).normalized()
		else:
			fly_direction = Vector2.from_angle(randf_range(0, TAU)).normalized()
		# Ensure direction isn't zero
		if fly_direction.is_zero_approx():
			fly_direction = Vector2.RIGHT

	# --- Vertical sine-bob for floating feel ---
	_fly_bob_time = fmod(_fly_bob_time + delta, TAU / FLY_BOB_FREQUENCY)
	# Derivative of sine: cos gives velocity direction, amplitude controls strength
	var bob_offset = cos(_fly_bob_time * FLY_BOB_FREQUENCY) * FLY_BOB_AMPLITUDE

	# --- Movement ---
	velocity = fly_direction * FLY_SPEED
	velocity.y += bob_offset

	# --- Flip sprite according to horizontal movement ---
	if abs(fly_direction.x) > 0.1:
		animated_sprite.flip_h = fly_direction.x < 0

	# --- Bounce off walls ---
	if is_on_wall():
		fly_direction = fly_direction.bounce(Vector2.RIGHT).normalized()
		# Don't let it get stuck in a wall-parallel state
		if fly_direction.is_zero_approx():
			fly_direction = Vector2.from_angle(randf_range(0, TAU)).normalized()
		velocity = fly_direction * FLY_SPEED

	if is_on_floor() or is_on_ceiling():
		fly_direction = fly_direction.bounce(Vector2.UP).normalized()
		if fly_direction.is_zero_approx():
			fly_direction = Vector2.from_angle(randf_range(0, TAU)).normalized()
		velocity = fly_direction * FLY_SPEED

	# --- Also try to detect player for the "seen" memory (even if we don't lunge) ---
	_check_player_detected()


func process_lunging_state(delta: float) -> void:
	velocity = lunge_direction * LUNGE_SPEED

	# Flip sprite toward lunge direction
	animated_sprite.flip_h = lunge_direction.x < 0

	lunge_timer -= delta
	if lunge_timer <= 0.0:
		current_state = State.COOLDOWN
		cooldown_timer = ATTACK_COOLDOWN


func process_cooldown_state(delta: float) -> void:
	velocity = Vector2.ZERO

	cooldown_timer -= delta
	if cooldown_timer <= 0.0:
		# Return to flying, pick a random direction
		fly_direction = Vector2.from_angle(randf_range(0, TAU)).normalized()
		direction_change_timer = DIRECTION_CHANGE_INTERVAL
		current_state = State.FLYING


func process_stunned_state(delta: float) -> void:
	velocity = Vector2.ZERO

	stun_timer -= delta
	if stun_timer <= 0.0:
		# Return to flying after stun
		fly_direction = Vector2.from_angle(randf_range(0, TAU)).normalized()
		direction_change_timer = DIRECTION_CHANGE_INTERVAL
		current_state = State.FLYING


func process_bouncing_state(delta: float) -> void:
	# Phase 1: Recoil away from the player
	if is_recoiling:
		recoil_timer -= delta
		velocity = bounce_direction * RECOIL_SPEED
		if recoil_timer <= 0.0:
			is_recoiling = false
			# Pick a random direction to start bouncing
			bounce_direction = Vector2.from_angle(randf_range(0, TAU)).normalized()
			velocity = bounce_direction * BOUNCE_SPEED
		return

	# Phase 2: Bounce around, reflecting off walls
	bounce_timer -= delta
	velocity = bounce_direction * BOUNCE_SPEED

	# Reflect off walls
	if is_on_wall():
		bounce_direction = bounce_direction.bounce(Vector2.RIGHT)
		bounce_direction = bounce_direction.normalized()
		velocity = bounce_direction * BOUNCE_SPEED

	# Reflect off floor/ceiling
	if is_on_floor() or is_on_ceiling():
		bounce_direction = bounce_direction.bounce(Vector2.UP)
		bounce_direction = bounce_direction.normalized()
		velocity = bounce_direction * BOUNCE_SPEED

	# -- Lunge interrupt during bounce! --
	# The boss can also lunge from the middle of bouncing if it detects the player
	lunge_check_timer -= delta
	if lunge_check_timer <= 0.0:
		lunge_check_timer = LUNGE_CHECK_INTERVAL
		if _check_player_detected():
			if randf() < 0.35:  # Slightly lower chance during bounce
				_start_lunge(_last_player_position)
				return

	# End bouncing after duration
	if bounce_timer <= 0.0:
		# Transition to flying instead of cooldown for smoother pacing
		fly_direction = Vector2.from_angle(randf_range(0, TAU)).normalized()
		direction_change_timer = DIRECTION_CHANGE_INTERVAL
		current_state = State.FLYING