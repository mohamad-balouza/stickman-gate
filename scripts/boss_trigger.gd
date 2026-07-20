extends Area2D
## Wakes the boss and seals the arena entrance when the player walks in.

@export var boss_path: NodePath = ^"../Boss"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	var boss := get_node_or_null(boss_path) as Boss
	if boss != null:
		boss.engage()
	queue_free()
