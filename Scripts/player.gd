extends CharacterBody2D

var unlocked_abilities = {

}

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const COYOTE_TIME = 0.2
const JUMP_BUFFER_TIME = 0.18

func _ready():
	unlocked_abilities = Main.unlocked_abilities



var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var double_jump_used := false
var dash_timer := 0.0

func _physics_process(delta: float) -> void:

	# Update dash timer
	if dash_timer > 0.0:
		dash_timer -= delta
	
	# Apply gravity when airborne (but not during dash)
	if not is_on_floor() and dash_timer <= 0.0:
		velocity.y += get_gravity().y * delta

	# Update coyote timer and reset double jump when landing
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		double_jump_used = false
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	# Update jump buffer
	if Input.is_action_just_pressed("up"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

	# Handle jump
	if jump_buffer_timer > 0.0:
		if coyote_timer > 0.0:
			# Normal jump (within coyote window or on ground)
			velocity.y = JUMP_VELOCITY
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
		elif unlocked_abilities.get("double_jump", false) and not double_jump_used:
			# Double jump (only once per airborne session)
			velocity.y = JUMP_VELOCITY
			jump_buffer_timer = 0.0
			double_jump_used = true
	if unlocked_abilities.get("dash", false) and Input.is_action_just_pressed("dash"):
		velocity.x = SPEED * (1 if velocity.x >= 0 else -1) * 2
		dash_timer = 0.2


	# Handle horizontal movement
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta)

	move_and_slide()
