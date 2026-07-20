extends Area2D
## Level goal. Touching it wins the level.

var _reached := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _reached or not body is Player:
		return
	_reached = true
	EventBus.bus.level_won.emit()
