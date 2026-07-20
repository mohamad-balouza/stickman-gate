class_name GameCamera
extends Camera2D
## Follows its parent scene's player (set externally as target) with
## trauma-based screen shake driven by EventBus.bus.shake.

const TRAUMA_DECAY := 1.6
const MAX_OFFSET := 6.0

@export var level_limits := Rect2i(0, 0, 2560, 384)

var _trauma := 0.0

func _ready() -> void:
	limit_left = level_limits.position.x
	limit_top = level_limits.position.y
	limit_right = level_limits.position.x + level_limits.size.x
	limit_bottom = level_limits.position.y + level_limits.size.y
	EventBus.bus.shake.connect(add_trauma)

func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)

func _process(delta: float) -> void:
	_trauma = maxf(_trauma - TRAUMA_DECAY * delta, 0.0)
	var s := _trauma * _trauma * MAX_OFFSET
	offset = Vector2(randf_range(-s, s), randf_range(-s, s))
