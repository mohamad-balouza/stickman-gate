class_name Enemy
extends CharacterBody2D
## Patrolling stickman. Turns at walls and ledges. Health, hurtbox and
## hitbox behaviour live in composed child components.

const GRAVITY := 1400.0
const MAX_FALL := 320.0
const PATROL_SPEED := 40.0
const KNOCK_TIME := 0.25

## Boss-summoned minions don't count toward the level kill goal.
@export var count_kill := true

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var hitbox: HitboxComponent = $Hitbox
@onready var wall_ray: RayCast2D = $WallRay
@onready var floor_ray: RayCast2D = $FloorRay
@onready var death_particles: CPUParticles2D = $DeathParticles
@onready var hit_sfx: AudioStreamPlayer2D = $HitSfx
@onready var die_sfx: AudioStreamPlayer2D = $DieSfx

var dir := -1
var _dead := false
var _knock := 0.0

func _ready() -> void:
	sprite.sprite_frames = SheetFrames.build(preload("res://assets/enemy_sheet.png"))
	sprite.play("run")
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/flash.gdshader")
	sprite.material = mat
	hit_sfx.stream = preload("res://assets/sfx/hit.wav")
	die_sfx.stream = preload("res://assets/sfx/enemy_die.wav")
	_config_death_particles()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	hurtbox.hit_taken.connect(_on_hit_taken)
	_apply_dir()

func _physics_process(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	if _dead:
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		move_and_slide()
		return
	if _knock > 0.0:
		_knock -= delta
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	else:
		if is_on_floor() and (wall_ray.is_colliding() or not floor_ray.is_colliding()):
			dir = -dir
			_apply_dir()
		velocity.x = dir * PATROL_SPEED
	move_and_slide()

func _apply_dir() -> void:
	sprite.flip_h = dir < 0
	wall_ray.target_position = Vector2(dir * 8.0, 0.0)
	floor_ray.position = Vector2(dir * 7.0, 0.0)

func _on_hit_taken(_damage: int, from_pos: Vector2, kb: float) -> void:
	if _dead:
		return
	var away := signf(global_position.x - from_pos.x)
	if away == 0.0:
		away = -signf(velocity.x) if velocity.x != 0.0 else 1.0
	velocity.x = away * kb
	velocity.y = -60.0
	_knock = KNOCK_TIME

func _on_damaged(_amount: int, _from_pos: Vector2) -> void:
	if _dead:
		return
	hit_sfx.pitch_scale = randf_range(0.9, 1.1)
	hit_sfx.play()
	EventBus.bus.shake.emit(0.25)
	var mat := sprite.material as ShaderMaterial
	mat.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.08)

func _on_died() -> void:
	_dead = true
	sprite.play("death")
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	hitbox.set_deferred("monitorable", false)
	death_particles.restart()
	death_particles.emitting = true
	die_sfx.play()
	EventBus.bus.shake.emit(0.35)
	if count_kill:
		EventBus.bus.enemy_killed.emit()
	_hitstop()
	await sprite.animation_finished
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _hitstop() -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.04, true, false, true).timeout
	Engine.time_scale = 1.0

func _config_death_particles() -> void:
	var p := death_particles
	p.emitting = false
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.local_coords = false
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2(0, 320)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.color = Color(0.62, 0.11, 0.12)
