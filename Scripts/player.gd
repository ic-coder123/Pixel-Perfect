extends CharacterBody2D

var unlocked_abilities = {}
var health := 100

@onready var keybinder: Control = $Control

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var actionable_finder: Area2D = $actionable_finder
@onready var sword_area: Area2D = $Sword

const SPEED = 300.0
const JUMP_VELOCITY = -450.0

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
	health = 100
	sword_area.monitoring = false
	sword_area.visible = false
	keybinder.visible = false

func _on_sword_hit(body: Node) -> void:
	if body == self: return

	# Pogo mechanic: Bounce up if attacking down on an enemy
	if current_state == State.ATTACK and is_equal_approx(sword_area.rotation, PI / 2):
		if body.is_in_group("enemy") or body.has_method("take_damage"):
			velocity.y = JUMP_VELOCITY
			current_state = State.AIR
			sword_area.set_deferred("monitoring", false)
			sword_area.visible = false
			double_jump_used = false




	if body.has_method("take_damage"):
		body.take_damage(10)
	elif body.is_in_group("enemy"):
		body.queue_free()

# helper called by death zones; uses autoload respawn helper
func respawn() -> void:
	Main.respawn_player(self)

# --- STATE MACHINE ---

enum State { IDLE, RUN, AIR, WALL_SLIDE, DASH, ATTACK }
var current_state = State.IDLE

var facing_direction := 1.0
var attack_timer := 0.0

var _was_attack_pressed := false


var coyote_timer := 0.0
var wall_coyote_timer := 0.0
var jump_buffer_timer := 0.0

var double_jump_used := false
var dash_timer := 0.0
var active_jump_tween: Tween

# cached wall normal during wall contact 
var last_wall_normal := Vector2.ZERO

var was_in_air := false

func _physics_process(delta: float) -> void:
	# 1. Update Global Timers & Inputs
	update_timers_and_input(delta)

	if is_on_floor() and was_in_air:
		apply_landing_squash()

	was_in_air =  not is_on_floor()
	# 2. State Logic
	match current_state:
		State.IDLE, State.RUN:
			process_ground_state(delta)
			animated_sprite.play("IDLE")
			animated_sprite.flip_h = facing_direction < 0

			
		State.AIR:
			process_air_state(delta)
	
		State.WALL_SLIDE:
			process_wall_slide_state(delta)
	
		State.DASH:
			process_dash_state(delta)
			animated_sprite.play("DASH")
			animated_sprite.flip_h = facing_direction < 0
				
		State.ATTACK:
			process_attack_state(delta)
	
	# 3. Physics Step
	move_and_slide()
	
	# 4. Transitions
	handle_state_transitions()




func apply_landing_squash():
	var land_tween = create_tween()
	# Squash down (Wide and Short)
	land_tween.tween_property(animated_sprite, "scale", Vector2(4.3, 3.7), 0.1).set_trans(Tween.TRANS_SINE)
	# Snap back
	land_tween.tween_property(animated_sprite, "scale", Vector2(4.0, 4), 0.1).set_trans(Tween.TRANS_SINE)

func take_damage(amount: int) -> void:
	health -= amount
	print("Player took damage! Health: ", health)
	if health <= 0:
		respawn()

func update_timers_and_input(delta: float) -> void:
	# Jump Buffer
	if Input.is_action_just_pressed("up"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	
	# Ground Coyote
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		double_jump_used = false
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)
	
	# Wall Coyote
	if unlocked_abilities.get("wall_jump", false) and is_on_wall_only():
		var n := get_wall_normal()
		if abs(n.x) > 0.6:
			last_wall_normal = n
			wall_coyote_timer = WALL_COYOTE_TIME
	else:
		wall_coyote_timer = max(wall_coyote_timer - delta, 0.0)
	
	
	var attack_pressed := Input.is_action_pressed("attack")
	if attack_pressed and not _was_attack_pressed:
		if current_state != State.ATTACK and current_state != State.DASH and current_state != State.WALL_SLIDE:
			perform_attack()
	_was_attack_pressed = attack_pressed

func process_ground_state(delta: float) -> void:
	handle_horizontal_movement(delta)
	
	if jump_buffer_timer > 0.0:
		perform_jump()
	
	if check_dash_input():
		start_dash()

func process_air_state(delta: float) -> void:
	velocity.y += get_gravity().y * delta
	handle_horizontal_movement(delta)
	
	# Variable Jump Height: Cut velocity if button released early
	if velocity.y < 0 and Input.is_action_just_released("up"):
		velocity.y *= 0.5
	
	if jump_buffer_timer > 0.0:
		if unlocked_abilities.get("wall_jump", false) and wall_coyote_timer > 0.0:
			perform_wall_jump()
		elif coyote_timer > 0.0:
			perform_jump()
		elif unlocked_abilities.get("double_jump", false) and not double_jump_used:
			perform_double_jump()
	
	if check_dash_input():
		start_dash()

func process_wall_slide_state(delta: float) -> void:
	velocity.y += get_gravity().y * delta
	
	# Wall Slide Friction
	var direction_into_wall := Input.get_axis("left", "right")
	# If holding towards wall (opposite of normal)
	if direction_into_wall != 0 and sign(direction_into_wall) == -sign(last_wall_normal.x):
		velocity.y = min(velocity.y, WALL_SLIDE_MAX_FALL_SPEED)
	
	handle_horizontal_movement(delta)
	
	if jump_buffer_timer > 0.0:
		perform_wall_jump()

func process_dash_state(delta: float) -> void:
	dash_timer -= delta

func process_attack_state(delta: float) -> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	attack_timer -= delta
	velocity.x = 0.0

func handle_state_transitions() -> void:

	if not current_state == State.DASH:
		animated_sprite.flip_h = facing_direction < 0
	match current_state:
		State.IDLE, State.RUN:
			if not is_on_floor():
				current_state = State.AIR
		State.AIR:
			if is_on_floor():
				current_state = State.IDLE
			elif unlocked_abilities.get("wall_jump", false) and is_on_wall_only():
				if abs(get_wall_normal().x) > 0.6:
					current_state = State.WALL_SLIDE
		State.WALL_SLIDE:
			if is_on_floor():
				current_state = State.IDLE
			elif not is_on_wall():
				current_state = State.AIR
		State.DASH:
			if dash_timer <= 0.0:
				current_state = State.IDLE if is_on_floor() else State.AIR
				velocity.x = move_toward(velocity.x, 0, SPEED * 0.1)
		State.ATTACK:
			if attack_timer <= 0.0:
				sword_area.set_deferred("monitoring", false)
				sword_area.visible = false
				current_state = State.IDLE

func handle_horizontal_movement(delta: float) -> void:
	# Use get_axis to prevent diagonal input (jumping) from slowing down X movement
	var direction := Input.get_axis("left", "right")
	
	if direction:
		velocity.x = direction * SPEED
		facing_direction = direction
		if current_state == State.IDLE: current_state = State.RUN
	else:
		# High friction for precise stopping (5x faster stop)
		velocity.x = move_toward(velocity.x, 0, SPEED * 5.0 * delta)
		if current_state == State.RUN: current_state = State.IDLE

func perform_jump():
	velocity.y = JUMP_VELOCITY
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	current_state = State.AIR
	
	# 1. Reset scale to normal first so the effect doesn't "stack"
	animated_sprite.scale = Vector2(4,4)
	
	# 2. Create the tween
	var size_tween = create_tween()
	
	# 3. Stretch UP (Skinny and Tall) - 0.1 seconds
	size_tween.tween_property(animated_sprite, "scale", Vector2(3.8, 4.2), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 4. Snap back to Normal - 0.1 seconds 
	size_tween.tween_property(animated_sprite, "scale", Vector2(4,4), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	



func perform_double_jump():
	velocity.y = JUMP_VELOCITY
	double_jump_used = true
	jump_buffer_timer = 0.0
	current_state = State.AIR

func perform_wall_jump():
	velocity.x = last_wall_normal.x * WALL_JUMP_PUSH
	velocity.y = WALL_JUMP_UP
	jump_buffer_timer = 0.0
	wall_coyote_timer = 0.0
	current_state = State.AIR

func perform_attack() -> void:
	current_state = State.ATTACK
	attack_timer = 0.3 # Duration of slash
	velocity = Vector2.ZERO
	animated_sprite.play("ATTACK")
	
	sword_area.rotation = 0
	# For vertical attacks, we don't want to flip the sword area based on facing direction.
	# So we reset scale and only apply facing_direction for horizontal slashes.
	sword_area.scale.x = 1.0
	sword_area.visible = true
	sword_area.set_deferred("monitoring", true)
	
	if Input.is_action_pressed("down"):
		sword_area.rotation = PI / 2
	elif Input.is_action_pressed("up"):
		sword_area.rotation = -PI / 2
	else: # Horizontal attack
		sword_area.scale.x = facing_direction

func check_dash_input() -> bool:
	return unlocked_abilities.get("dash", false) and Input.is_action_just_pressed("dash")

func start_dash():
	var dash_dir = facing_direction
	if velocity.x != 0:
		dash_dir = sign(velocity.x)
	velocity.x = SPEED * dash_dir * 2
	dash_timer = 0.2
	current_state = State.DASH

func _process(_delta):
	# HANDLE ACTION / DIALOGUE
	
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
		var actionables = actionable_finder.get_overlapping_areas()
		if actionables.size() > 0:
			# Trigger the dialogue
			print("interacting")
			actionables[0].action()
			return

	if Input.is_action_just_pressed("ui_cancel"):
		keybinder.visible = !keybinder.visible
		if not keybinder.visible:
			# Release focus so UI doesn't steal 'ui_accept' input
			var focused = get_viewport().gui_get_focus_owner()
			if focused:
				focused.release_focus()
