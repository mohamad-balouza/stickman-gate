class_name HurtboxComponent
extends Area2D
## Receives hits (from bullets calling take_hit, or from overlapping
## HitboxComponents) and forwards damage to its HealthComponent.
## Optionally grants i-frames after each hit.

signal hit_taken(damage: int, from_pos: Vector2, knockback: float)

@export var health: HealthComponent
@export var invincible_time: float = 0.0
## Extra damage taken while true (e.g. a boss stun window).
@export var damage_multiplier: float = 1.0

## External invulnerability (e.g. player dash) — independent of hit i-frames.
var shield := false

var _invincible := false

func _ready() -> void:
	if health == null:
		health = get_parent().get_node_or_null("HealthComponent")

func can_take_hit() -> bool:
	return not _invincible and not shield and health != null and not health.is_dead()

func take_hit(damage: int, from_pos: Vector2, knockback: float = 0.0) -> bool:
	if not can_take_hit():
		return false
	var total := maxi(1, roundi(damage * damage_multiplier))
	hit_taken.emit(total, from_pos, knockback)
	health.take_damage(total, from_pos)
	if invincible_time > 0.0 and not health.is_dead():
		_start_iframes()
	return true

func _physics_process(_delta: float) -> void:
	# Contact damage: only relevant for hurtboxes whose mask can see
	# HitboxComponents (the player). Re-checks every frame so standing
	# on an enemy re-damages once i-frames expire.
	if not monitoring:
		return
	for area in get_overlapping_areas():
		var hb := area as HitboxComponent
		if hb != null and take_hit(hb.damage, hb.global_position, hb.knockback):
			break

func _start_iframes() -> void:
	_invincible = true
	var target := get_parent() as Node2D
	var tw := create_tween()
	tw.set_loops(int(invincible_time / 0.1))
	tw.tween_property(target, "modulate:a", 0.25, 0.05)
	tw.tween_property(target, "modulate:a", 1.0, 0.05)
	tw.finished.connect(func() -> void:
		target.modulate.a = 1.0
		_invincible = false
	)
