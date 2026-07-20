class_name BossProjectile
extends HitboxComponent
## Boss attack projectile. Being a HitboxComponent, the player's
## hurtbox contact scan damages the player automatically on overlap.

enum Kind { SKULL, ORB, SHOCKWAVE }

const TEX_SKULL := preload("res://assets/skull.png")
const TEX_ORB := preload("res://assets/orb.png")
const TEX_SHOCKWAVE := preload("res://assets/shockwave.png")

var kind := Kind.ORB
var velocity := Vector2.ZERO
var grav := 0.0
var bounces_left := 0
var _life := 3.5
var _dying := false

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(p_kind: Kind, pos: Vector2, vel: Vector2) -> void:
	kind = p_kind
	global_position = pos
	velocity = vel
	match kind:
		Kind.SKULL:
			sprite.texture = TEX_SKULL
			grav = 700.0
			bounces_left = 1
			_life = 4.0
		Kind.ORB:
			sprite.texture = TEX_ORB
			grav = 0.0
			_life = 3.5
		Kind.SHOCKWAVE:
			sprite.texture = TEX_SHOCKWAVE
			grav = 0.0
			_life = 3.5
			sprite.flip_h = vel.x < 0.0
			sprite.position.y = -4.0

func _physics_process(delta: float) -> void:
	if _dying:
		return
	velocity.y += grav * delta
	# world geometry via ray (Area2D can't see TileMapLayer bodies)
	var next := global_position + velocity * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, next, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit:
		if kind == Kind.SKULL and bounces_left > 0 and velocity.y > 0.0:
			bounces_left -= 1
			global_position = hit.position + Vector2(0, -3)
			velocity.y = -absf(velocity.y) * 0.55
		else:
			global_position = hit.position
			_die(true)
			return
	else:
		global_position = next
	_life -= delta
	match kind:
		Kind.SKULL:
			sprite.rotation += 9.0 * delta * signf(velocity.x)
		Kind.ORB:
			sprite.modulate.a = 0.75 + 0.25 * sin(_life * 18.0)
	if _life <= 0.0:
		_die(false)

func _on_body_entered(body: Node) -> void:
	if _dying:
		return
	if body is Player:
		_die(true)

func _die(burst: bool) -> void:
	_dying = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	sprite.visible = false
	if burst:
		var p := CPUParticles2D.new()
		p.one_shot = true
		p.emitting = true
		p.amount = 6
		p.lifetime = 0.25
		p.explosiveness = 1.0
		p.spread = 180.0
		p.initial_velocity_min = 30.0
		p.initial_velocity_max = 80.0
		p.gravity = Vector2(0, 160)
		p.scale_amount_min = 1.0
		p.scale_amount_max = 2.0
		p.color = Color(1.0, 0.45, 0.35) if kind != Kind.SHOCKWAVE else Color(0.66, 0.56, 0.43)
		add_child(p)
	await get_tree().create_timer(0.35).timeout
	queue_free()
