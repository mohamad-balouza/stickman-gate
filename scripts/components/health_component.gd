class_name HealthComponent
extends Node
## Owns hit points for whatever it is attached to.

signal health_changed(hp: int, max_hp: int)
signal damaged(amount: int, from_pos: Vector2)
signal died

@export var max_hp: int = 3

var hp: int

func _ready() -> void:
	hp = max_hp

func take_damage(amount: int, from_pos: Vector2 = Vector2.ZERO) -> void:
	if hp <= 0:
		return
	hp = maxi(hp - amount, 0)
	health_changed.emit(hp, max_hp)
	damaged.emit(amount, from_pos)
	if hp == 0:
		died.emit()

func is_dead() -> bool:
	return hp <= 0
