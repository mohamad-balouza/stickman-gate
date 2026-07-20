class_name BulletPool
extends Node2D
## Preallocates every bullet and impact-particle node at scene load.
## Zero instancing happens during gameplay.

const POOL_SIZE := 32
const IMPACT_POOL_SIZE := 8

var _bullets: Array[Bullet] = []
var _impacts: Array[CPUParticles2D] = []
var _next := 0
var _next_impact := 0

func _ready() -> void:
	add_to_group("bullet_pool")
	var bullet_scene: PackedScene = load("res://scenes/bullet.tscn")
	for i in POOL_SIZE:
		var b := bullet_scene.instantiate() as Bullet
		b.pool = self
		add_child(b)
		b.deactivate()
		_bullets.append(b)
	for i in IMPACT_POOL_SIZE:
		var p := _make_impact()
		add_child(p)
		_impacts.append(p)

func fire(pos: Vector2, dir: Vector2, stats: WeaponStats) -> void:
	var b := _bullets[_next]
	_next = (_next + 1) % POOL_SIZE
	b.activate(pos, dir, stats)

func spawn_impact(pos: Vector2, hit_enemy: bool) -> void:
	var p := _impacts[_next_impact]
	_next_impact = (_next_impact + 1) % IMPACT_POOL_SIZE
	p.global_position = pos
	p.color = Color(1.0, 0.45, 0.35) if hit_enemy else Color(1.0, 0.85, 0.4)
	p.restart()
	p.emitting = true

func active_bullet_count() -> int:
	var n := 0
	for b in _bullets:
		if b.is_active():
			n += 1
	return n

func _make_impact() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 6
	p.lifetime = 0.25
	p.explosiveness = 1.0
	p.local_coords = false
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2(0, 220)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	return p
