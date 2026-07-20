class_name Bullet
extends Area2D
## Pooled projectile. Never instantiated at runtime — BulletPool
## preallocates and recycles these via activate()/deactivate().

var damage := 1
var knockback := 0.0
var velocity := Vector2.ZERO
var pool: Node = null

var _life := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func activate(pos: Vector2, dir: Vector2, stats: WeaponStats) -> void:
	global_position = pos
	rotation = dir.angle()
	velocity = dir * stats.bullet_speed
	damage = stats.damage
	knockback = stats.knockback
	modulate = stats.bullet_modulate
	_life = stats.bullet_range / maxf(stats.bullet_speed, 1.0)
	visible = true
	set_deferred("monitoring", true)
	set_physics_process(true)

func deactivate() -> void:
	visible = false
	velocity = Vector2.ZERO
	set_deferred("monitoring", false)
	set_physics_process(false)
	global_position = Vector2(-1000.0, -1000.0)

func is_active() -> bool:
	return is_physics_processing()

func _physics_process(delta: float) -> void:
	# Area2D never sees TileMapLayer static colliders via body_entered,
	# so world geometry is hit-tested with a ray along the travel path.
	var next := global_position + velocity * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, next, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit:
		global_position = hit.position
		pool.spawn_impact(global_position, false)
		deactivate()
		return
	global_position = next
	_life -= delta
	if _life <= 0.0:
		deactivate()

func _on_body_entered(body: Node) -> void:
	if not is_active():
		return
	if body is CharacterBody2D:
		# Actors take damage through their HurtboxComponent (area), not
		# their physics body — ignore so area_entered can process.
		return
	pool.spawn_impact(global_position, false)
	deactivate()

func _on_area_entered(area: Area2D) -> void:
	if not is_active():
		return
	var hurt := area as HurtboxComponent
	if hurt != null and hurt.take_hit(damage, global_position, knockback):
		pool.spawn_impact(global_position, true)
		deactivate()
