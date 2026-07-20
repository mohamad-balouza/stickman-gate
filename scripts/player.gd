class_name Player
extends CharacterBody2D
## Movement and game-feel. Health/hurtbox/weapon behaviour live in
## composed child components.

const RUN_SPEED := 130.0
const GROUND_ACCEL := 1100.0
const GROUND_FRICTION := 1400.0
const AIR_ACCEL := 700.0
const AIR_FRICTION := 250.0
const GRAVITY_UP := 850.0
const GRAVITY_DOWN := 1400.0
const MAX_FALL := 320.0
const JUMP_VELOCITY := -310.0
const JUMP_CUT := 0.45
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12
const KILL_FLOOR_Y := 420.0
const DASH_SPEED := 340.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.6

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var weapon: WeaponComponent = $Weapon
@onready var run_dust: CPUParticles2D = $RunDust
@onready var land_dust: CPUParticles2D = $LandDust
@onready var jump_sfx: AudioStreamPlayer2D = $JumpSfx
@onready var hurt_sfx: AudioStreamPlayer2D = $HurtSfx
@onready var dash_sfx: AudioStreamPlayer2D = $DashSfx

var facing := 1
var dead := false
var _coyote := 0.0
var _buffer := 0.0
var _was_on_floor := false
var _dash_left := 0.0
var _dash_cd := 0.0
var _ghost_timer := 0.0

func _ready() -> void:
	sprite.sprite_frames = SheetFrames.build(preload("res://assets/player_sheet.png"))
	sprite.play("idle")
	jump_sfx.stream = preload("res://assets/sfx/jump.wav")
	hurt_sfx.stream = preload("res://assets/sfx/hit.wav")
	dash_sfx.stream = preload("res://assets/sfx/dash.wav")
	_config_dust()
	health.health_changed.connect(func(hp: int, m: int) -> void:
		EventBus.bus.player_health_changed.emit(hp, m))
	health.died.connect(_on_died)
	hurtbox.hit_taken.connect(_on_hit_taken)

func _physics_process(delta: float) -> void:
	if dead:
		velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
		velocity.y = minf(velocity.y + GRAVITY_DOWN * delta, MAX_FALL)
		move_and_slide()
		return

	if global_position.y > KILL_FLOOR_Y:
		health.take_damage(health.hp)
		return

	_dash_cd = maxf(_dash_cd - delta, 0.0)
	if _dash_left > 0.0:
		_dash_tick(delta)
		return
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		_start_dash()
		return

	var axis := Input.get_axis("move_left", "move_right")
	var on_floor := is_on_floor()

	_coyote = COYOTE_TIME if on_floor else maxf(_coyote - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER
	else:
		_buffer = maxf(_buffer - delta, 0.0)

	var target_speed := axis * RUN_SPEED
	var accel: float
	if absf(target_speed) > 0.01:
		accel = GROUND_ACCEL if on_floor else AIR_ACCEL
	else:
		accel = GROUND_FRICTION if on_floor else AIR_FRICTION
	velocity.x = move_toward(velocity.x, target_speed, accel * delta)

	var g := GRAVITY_UP if velocity.y < 0.0 else GRAVITY_DOWN
	velocity.y = minf(velocity.y + g * delta, MAX_FALL)

	if _buffer > 0.0 and _coyote > 0.0:
		_buffer = 0.0
		_coyote = 0.0
		velocity.y = JUMP_VELOCITY
		sprite.scale = Vector2(0.78, 1.22)
		jump_sfx.pitch_scale = randf_range(0.95, 1.05)
		jump_sfx.play()
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT

	move_and_slide()

	if is_on_floor() and not _was_on_floor:
		sprite.scale = Vector2(1.25, 0.75)
		land_dust.restart()
		land_dust.emitting = true
	_was_on_floor = is_on_floor()

	if axis != 0.0:
		facing = 1 if axis > 0.0 else -1
	sprite.flip_h = facing < 0
	weapon.scale.x = facing
	sprite.scale = sprite.scale.lerp(Vector2.ONE, minf(10.0 * delta, 1.0))

	run_dust.emitting = is_on_floor() and absf(velocity.x) > 60.0

	if Input.is_action_pressed("shoot"):
		weapon.try_fire(Vector2(facing, 0.0))

	_update_anim(axis, is_on_floor())

func _start_dash() -> void:
	var axis := Input.get_axis("move_left", "move_right")
	if axis != 0.0:
		facing = 1 if axis > 0.0 else -1
		sprite.flip_h = facing < 0
		weapon.scale.x = facing
	_dash_left = DASH_TIME
	_dash_cd = DASH_COOLDOWN
	_ghost_timer = 0.0
	hurtbox.shield = true
	sprite.scale = Vector2(1.35, 0.72)
	dash_sfx.pitch_scale = randf_range(0.95, 1.1)
	dash_sfx.play()

func _dash_tick(delta: float) -> void:
	_dash_left -= delta
	velocity = Vector2(facing * DASH_SPEED, 0.0)
	move_and_slide()
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_ghost_timer = 0.045
		_spawn_ghost()
	if _dash_left <= 0.0:
		hurtbox.shield = false
		velocity.x = facing * RUN_SPEED

func _spawn_ghost() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.flip_h = sprite.flip_h
	ghost.global_position = sprite.global_position
	ghost.scale = sprite.scale
	ghost.modulate = Color(0.35, 0.72, 1.0, 0.55)
	ghost.z_index = -1
	get_parent().add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ghost.queue_free)

func _update_anim(axis: float, on_floor: bool) -> void:
	if not on_floor:
		sprite.play("jump" if velocity.y < 0.0 else "fall")
	elif absf(axis) > 0.1:
		sprite.play("run")
	else:
		sprite.play("idle")

func _on_hit_taken(_damage: int, from_pos: Vector2, kb: float) -> void:
	if dead:
		return
	var dir := signf(global_position.x - from_pos.x)
	if dir == 0.0:
		dir = -float(facing)
	velocity = Vector2(dir * kb, -120.0)
	hurt_sfx.play()
	EventBus.bus.shake.emit(0.5)

func _on_died() -> void:
	dead = true
	sprite.play("death")
	velocity = Vector2.ZERO
	hurtbox.set_deferred("monitoring", false)
	run_dust.emitting = false
	EventBus.bus.player_died.emit()

func _config_dust() -> void:
	for dust: CPUParticles2D in [run_dust, land_dust]:
		dust.emitting = false
		dust.lifetime = 0.35
		dust.local_coords = false
		dust.direction = Vector2(0, -1)
		dust.spread = 40.0
		dust.gravity = Vector2(0, -20)
		dust.initial_velocity_min = 10.0
		dust.initial_velocity_max = 30.0
		dust.scale_amount_min = 1.0
		dust.scale_amount_max = 2.0
		dust.color = Color(0.76, 0.7, 0.6, 0.85)
		dust.position = Vector2(0, 14)
	run_dust.amount = 6
	land_dust.amount = 8
	land_dust.one_shot = true
	land_dust.explosiveness = 1.0
	land_dust.spread = 70.0
	land_dust.initial_velocity_min = 20.0
	land_dust.initial_velocity_max = 45.0
