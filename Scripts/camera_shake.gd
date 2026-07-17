extends Camera2D

# Screen shake parameters
@export var SHAKE_DECAY_RATE := 8.0
@export var SHAKE_SCALE := 8.0

var _trauma := 0.0
var _shake_offset := Vector2.ZERO


func add_trauma(amount: float) -> void:
	_trauma = min(_trauma + amount, 1.0)


func _process(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = max(_trauma - SHAKE_DECAY_RATE * delta, 0.0)
		var shake_power := _trauma * _trauma * SHAKE_SCALE
		_shake_offset = Vector2(
			randf_range(-shake_power, shake_power),
			randf_range(-shake_power, shake_power)
		)
		offset = _shake_offset
	else:
		offset = Vector2.ZERO
		_shake_offset = Vector2.ZERO
