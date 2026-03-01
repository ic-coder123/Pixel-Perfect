extends CharacterBody2D

var unlocked_abilities = {}

@onready var actionable_finder: Area2D = $actionable_finder

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

const COYOTE_TIME = 0.2
const JUMP_BUFFER_TIME = 0.18

# Wall jump tuning
const WALL_COYOTE_TIME := 0.12
const WALL_JUMP_PUSH := 340.0
const WALL_JUMP_UP := -420.0
const WALL_SLIDE_MAX_FALL_SPEED := 220.0

func _ready():
	unlocked_abilities = Main.unlocked_abilities
	# make sure the player is in a known group so checkpoint/death zones can identify it
	if not is_in_group("player"):
		add_to_group("player")

# helper called by death zones; uses autoload respawn helper
func respawn() -> void:
	Main.respawn_player(self)




var coyote_timer := 0.0
var wall_coyote_timer := 0.0
var jump_buffer_timer := 0.0

var double_jump_used := false
var dash_timer := 0.0

# cached wall normal during wall contact (points away from wall)
var last_wall_normal := Vector2.ZERO

func _physics_process(delta: float) -> void:
	# Update dash timer
	if dash_timer > 0.0:
		dash_timer -= delta

	# Apply gravity when airborne (but not during dash)
	if not is_on_floor() and dash_timer <= 0.0:
		velocity.y += get_gravity().y * delta

	# --- Ground coyote / reset airborne state
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		wall_coyote_timer = 0.0
		double_jump_used = false
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	# --- Wall contact tracking (for vertical walls)
	if unlocked_abilities.get("wall_jump", false) and is_on_wall_only():
		var n := get_wall_normal()
		# We only care about mostly-horizontal normals => vertical surfaces
		if abs(n.x) > 0.6:
			last_wall_normal = n
			wall_coyote_timer = WALL_COYOTE_TIME

			# Optional wall slide: cap fall speed while pressing into the wall
			var direction_into_wall := 0
			if Input.is_action_pressed("left"):
				direction_into_wall = -1
			elif Input.is_action_pressed("right"):
				direction_into_wall = 1

			# If player is holding towards the wall (opposite of normal), slow descent
			if direction_into_wall != 0 and sign(direction_into_wall) == -sign(n.x):
				velocity.y = min(velocity.y, WALL_SLIDE_MAX_FALL_SPEED)
	else:
		wall_coyote_timer = max(wall_coyote_timer - delta, 0.0)
		if wall_coyote_timer == 0.0:
			last_wall_normal = Vector2.ZERO

	# --- Jump buffer
	if Input.is_action_just_pressed("up"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

	# --- Handle jumps (priority: wall -> ground -> double jump)
	if jump_buffer_timer > 0.0:
		var did_jump := false

		# Wall jump (requires touching wall or within wall coyote window)
		if not is_on_floor() and unlocked_abilities.get("wall_jump", false) and wall_coyote_timer > 0.0 and abs(last_wall_normal.x) > 0.0:
			velocity.x = last_wall_normal.x * WALL_JUMP_PUSH
			velocity.y = WALL_JUMP_UP
			did_jump = true

		# Normal jump (ground/coyote)
		elif coyote_timer > 0.0:
			velocity.y = JUMP_VELOCITY
			did_jump = true
			coyote_timer = 0.0

		# Double jump
		elif unlocked_abilities.get("double_jump", false) and not double_jump_used:
			velocity.y = JUMP_VELOCITY
			double_jump_used = true
			did_jump = true

		if did_jump:
			jump_buffer_timer = 0.0
			wall_coyote_timer = 0.0

	# Dash
	if unlocked_abilities.get("dash", false) and Input.is_action_just_pressed("dash"):
		velocity.x = SPEED * (1 if velocity.x >= 0 else -1) * 2
		dash_timer = 0.2

	# Horizontal movement
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta)

	move_and_slide()

func _process(_delta):
	# HANDLE ACTION / DIALOGUE
	if Input.is_action_just_pressed("ui_accept"):
		var actionables = actionable_finder.get_overlapping_areas()
		if actionables.size() > 0:
			# Trigger the dialogue
			actionables[0].action()
			return
