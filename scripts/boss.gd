class_name Boss
extends CharacterBody2D
## "THE AMALGAM" — an abomination of fused stickmen guarding the exit
## gate. Six telegraphed attack patterns, enrage phase below half HP,
## and a stun window after crashing a charge into an arena wall.

enum State { DORMANT, COOLDOWN, ATTACKING, STUNNED, DEAD }

const GRAVITY := 1400.0
const MAX_FALL := 500.0
const BOSS_NAME := "THE AMALGAM"

@export var arena_left: float = 1992.0
@export var arena_right: float = 2424.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var contact_hitbox: HitboxComponent = $ContactHitbox
@onready var whip_hitbox: HitboxComponent = $WhipHitbox
@onready var whip_shape: CollisionShape2D = $WhipHitbox/Shape
@onready var whip_arm: Line2D = $WhipArm
@onready var slam_dust: CPUParticles2D = $SlamDust
@onready var charge_dust: CPUParticles2D = $ChargeDust
@onready var summon_swirl: CPUParticles2D = $SummonSwirl
@onready var stun_stars: CPUParticles2D = $StunStars
@onready var death_burst: CPUParticles2D = $DeathBurst
@onready var roar_sfx: AudioStreamPlayer2D = $RoarSfx
@onready var slam_sfx: AudioStreamPlayer2D = $SlamSfx
@onready var whip_sfx: AudioStreamPlayer2D = $WhipSfx
@onready var summon_sfx: AudioStreamPlayer2D = $SummonSfx
@onready var charge_sfx: AudioStreamPlayer2D = $ChargeSfx
@onready var shoot_sfx: AudioStreamPlayer2D = $ShootSfx
@onready var stun_sfx: AudioStreamPlayer2D = $StunSfx
@onready var hit_sfx: AudioStreamPlayer2D = $HitSfx
@onready var die_sfx: AudioStreamPlayer2D = $DieSfx

var state := State.DORMANT
var phase2 := false
var facing := -1
var _charging := false
var _attack_bag: Array[String] = []

const PROJECTILE_SCENE := "res://scenes/boss_projectile.tscn"
const ENEMY_SCENE := "res://scenes/enemy.tscn"

func _ready() -> void:
	sprite.sprite_frames = SheetFrames.build_boss(preload("res://assets/boss_sheet.png"))
	sprite.play("idle")
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/flash.gdshader")
	sprite.material = mat
	roar_sfx.stream = preload("res://assets/sfx/boss_roar.wav")
	slam_sfx.stream = preload("res://assets/sfx/boss_slam.wav")
	whip_sfx.stream = preload("res://assets/sfx/boss_whip.wav")
	summon_sfx.stream = preload("res://assets/sfx/boss_summon.wav")
	charge_sfx.stream = preload("res://assets/sfx/boss_charge.wav")
	shoot_sfx.stream = preload("res://assets/sfx/boss_shoot.wav")
	stun_sfx.stream = preload("res://assets/sfx/boss_stun.wav")
	hit_sfx.stream = preload("res://assets/sfx/hit.wav")
	die_sfx.stream = preload("res://assets/sfx/boss_die.wav")
	whip_arm.visible = false
	whip_shape.set_deferred("disabled", true)
	_config_particles()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.health_changed.connect(func(hp: int, max_hp: int) -> void:
		EventBus.bus.boss_health_changed.emit(hp, max_hp))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	elif velocity.y > 0.0:
		velocity.y = 0.0
	if state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	elif _charging:
		charge_dust.emitting = true
	elif state != State.ATTACKING:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	move_and_slide()
	if _charging and (is_on_wall() or global_position.x <= arena_left or global_position.x >= arena_right):
		_charging = false

func engage() -> void:
	if state != State.DORMANT:
		return
	state = State.COOLDOWN
	roar_sfx.play()
	EventBus.bus.shake.emit(0.7)
	EventBus.bus.boss_engaged.emit(BOSS_NAME, health.max_hp)
	_run_ai()

func _alive() -> bool:
	return state != State.DEAD and is_instance_valid(self)

func _player() -> Player:
	var nodes := get_tree().get_nodes_in_group("player")
	return nodes[0] as Player if not nodes.is_empty() else null

func _face_player() -> void:
	var p := _player()
	if p == null:
		return
	facing = 1 if p.global_position.x > global_position.x else -1
	sprite.flip_h = facing > 0

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _run_ai() -> void:
	await _wait(1.2)
	while _alive():
		state = State.COOLDOWN
		sprite.play("idle")
		await _wait(0.7 if phase2 else 1.4)
		if not _alive():
			return
		var p := _player()
		if p == null or p.dead:
			continue
		state = State.ATTACKING
		_face_player()
		await call(_pick_attack())
		if not _alive():
			return

func _pick_attack() -> String:
	if _attack_bag.is_empty():
		_attack_bag = ["atk_slam", "atk_whip", "atk_heads", "atk_summon", "atk_charge", "atk_orbs"]
		_attack_bag.shuffle()
	var p := _player()
	# prefer whip/slam up close, ranged attacks from afar
	if p != null:
		var d := absf(p.global_position.x - global_position.x)
		if d < 90.0 and _attack_bag.has("atk_whip"):
			_attack_bag.erase("atk_whip")
			return "atk_whip"
		if d > 220.0 and _attack_bag.has("atk_charge"):
			_attack_bag.erase("atk_charge")
			return "atk_charge"
	return _attack_bag.pop_front()

func _telegraph(time: float) -> void:
	sprite.play("windup")
	var mat := sprite.material as ShaderMaterial
	var tw := create_tween().set_loops(maxi(2, int(time / 0.18)))
	tw.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("flash", v), 0.55, 0.0, 0.18)
	await _wait(time)
	tw.kill()
	mat.set_shader_parameter("flash", 0.0)

# ---------------------------------------------------------------- attacks

## 1. Leap at the player and slam down, sending shockwaves both ways.
func atk_slam() -> void:
	await _telegraph(0.55)
	if not _alive():
		return
	var p := _player()
	var dir := facing
	if p != null:
		dir = 1 if p.global_position.x > global_position.x else -1
	sprite.play("lunge")
	velocity = Vector2(dir * 170.0, -430.0)
	await _wait(0.25)
	while _alive() and not is_on_floor():
		await get_tree().physics_frame
	if not _alive():
		return
	velocity.x = 0.0
	slam_sfx.play()
	EventBus.bus.shake.emit(0.85)
	slam_dust.restart()
	slam_dust.emitting = true
	_hitstop(0.03)
	for d in [-1.0, 1.0]:
		_spawn_projectile(BossProjectile.Kind.SHOCKWAVE,
			global_position + Vector2(d * 40.0, 34.0),
			Vector2(d * (170.0 if phase2 else 140.0), 0.0))
	await _wait(0.5)

## 2. Long telegraphed arm whip that sweeps the ground in front.
func atk_whip() -> void:
	_face_player()
	whip_arm.visible = true
	whip_arm.default_color = Color(0.16, 0.17, 0.3)
	whip_arm.points = PackedVector2Array([Vector2(facing * 14, 6), Vector2(facing * 22, 20)])
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		whip_arm.points = PackedVector2Array([
			Vector2(facing * 14, 6), Vector2(facing * (22 + 30 * v), 20 + 8 * v)]),
		0.0, 1.0, 0.45)
	await _telegraph(0.5)
	if not _alive():
		whip_arm.visible = false
		return
	# strike: arm snaps out full length at ground height
	whip_sfx.play()
	whip_arm.default_color = Color(0.95, 0.9, 0.85)
	whip_arm.points = PackedVector2Array([Vector2(facing * 14, 6), Vector2(facing * 110, 30)])
	whip_hitbox.position = Vector2(facing * 62, 28)
	whip_shape.set_deferred("disabled", false)
	EventBus.bus.shake.emit(0.35)
	await _wait(0.16)
	whip_shape.set_deferred("disabled", true)
	if not _alive():
		whip_arm.visible = false
		return
	var tw2 := create_tween()
	tw2.tween_method(func(v: float) -> void:
		whip_arm.points = PackedVector2Array([
			Vector2(facing * 14, 6), Vector2(facing * (110 - 88 * v), 30 - 10 * v)]),
		0.0, 1.0, 0.2)
	tw2.tween_callback(func() -> void: whip_arm.visible = false)
	await _wait(0.3)

## 3. Lob a volley of severed stickman heads in arcs.
func atk_heads() -> void:
	await _telegraph(0.5)
	if not _alive():
		return
	sprite.play("lunge")
	var p := _player()
	var count := 6 if phase2 else 4
	for i in count:
		if not _alive():
			return
		var tx := global_position.x + facing * randf_range(60.0, 260.0)
		if p != null:
			tx = p.global_position.x + randf_range(-70.0, 70.0)
		var dx := tx - global_position.x
		var vy := -300.0
		var t := 0.8
		var vx := dx / t
		shoot_sfx.pitch_scale = randf_range(0.85, 1.2)
		shoot_sfx.play()
		_spawn_projectile(BossProjectile.Kind.SKULL,
			global_position + Vector2(0, -40.0), Vector2(vx, vy))
		await _wait(0.14)
	await _wait(0.5)

## 4. Screech and disgorge stickman minions from the mass.
func atk_summon() -> void:
	summon_sfx.play()
	summon_swirl.restart()
	summon_swirl.emitting = true
	await _telegraph(0.7)
	if not _alive():
		return
	var minions := get_tree().get_nodes_in_group("minions")
	var room := 3 - minions.size()
	var enemy_scene: PackedScene = load(ENEMY_SCENE)
	for i in mini(2, room):
		var e := enemy_scene.instantiate()
		e.count_kill = false
		e.position = global_position + Vector2((-1 if i == 0 else 1) * 34.0, -20.0)
		e.add_to_group("minions")
		get_parent().add_child(e)
		e.velocity = Vector2((-1 if i == 0 else 1) * 90.0, -220.0)
	EventBus.bus.shake.emit(0.3)
	await _wait(0.5)

## 5. Telegraphed charge across the arena; crashing into a wall stuns
##    the boss and doubles damage taken — the punish window.
func atk_charge() -> void:
	_face_player()
	charge_sfx.play()
	await _telegraph(0.75)
	if not _alive():
		return
	sprite.play("lunge")
	_charging = true
	velocity.x = facing * (430.0 if phase2 else 370.0)
	var frames := 0
	while _alive() and _charging and frames < 180:
		EventBus.bus.shake.emit(0.06)
		await get_tree().physics_frame
		frames += 1
	charge_dust.emitting = false
	if not _alive():
		return
	# wall crash -> stunned punish window
	velocity.x = 0.0
	slam_sfx.play()
	stun_sfx.play()
	EventBus.bus.shake.emit(0.95)
	slam_dust.restart()
	slam_dust.emitting = true
	_hitstop(0.04)
	state = State.STUNNED
	sprite.play("windup")
	sprite.speed_scale = 0.35
	stun_stars.emitting = true
	hurtbox.damage_multiplier = 2.0
	sprite.self_modulate = Color(0.75, 0.8, 1.0)
	await _wait(1.3 if phase2 else 1.8)
	hurtbox.damage_multiplier = 1.0
	sprite.self_modulate = Color.WHITE
	sprite.speed_scale = 1.0
	stun_stars.emitting = false

## 6. Hop and release a radial ring of slow energy orbs.
func atk_orbs() -> void:
	await _telegraph(0.6)
	if not _alive():
		return
	sprite.play("lunge")
	velocity.y = -240.0
	await _wait(0.3)
	if not _alive():
		return
	var count := 10 if phase2 else 8
	shoot_sfx.pitch_scale = 0.7
	shoot_sfx.play()
	EventBus.bus.shake.emit(0.45)
	for i in count:
		var ang := TAU * i / count - PI / 2.0
		_spawn_projectile(BossProjectile.Kind.ORB,
			global_position + Vector2(0, -20.0),
			Vector2.from_angle(ang) * 115.0)
	await _wait(0.6)

# ---------------------------------------------------------------- reactions

func _on_damaged(_amount: int, _from_pos: Vector2) -> void:
	if state == State.DEAD:
		return
	hit_sfx.pitch_scale = randf_range(0.7, 0.85)
	hit_sfx.play()
	var mat := sprite.material as ShaderMaterial
	mat.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.07)
	if not phase2 and health.hp <= health.max_hp / 2:
		phase2 = true
		roar_sfx.pitch_scale = 0.8
		roar_sfx.play()
		EventBus.bus.shake.emit(0.8)
		EventBus.bus.toast.emit("THE AMALGAM IS ENRAGED!")
		sprite.self_modulate = Color(1.2, 0.82, 0.82)

func _on_died() -> void:
	state = State.DEAD
	_charging = false
	whip_arm.visible = false
	whip_shape.set_deferred("disabled", true)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	contact_hitbox.set_deferred("monitorable", false)
	stun_stars.emitting = false
	charge_dust.emitting = false
	sprite.speed_scale = 1.0
	sprite.self_modulate = Color.WHITE
	sprite.play("death")
	die_sfx.play()
	EventBus.bus.shake.emit(1.0)
	_hitstop(0.09)
	# clear lingering hazards so the victory lap is safe
	for node in get_parent().get_children():
		if node is BossProjectile:
			node._die(false)
	for minion in get_tree().get_nodes_in_group("minions"):
		if is_instance_valid(minion) and minion is Enemy and not minion._dead:
			minion.health.take_damage(999, global_position)
	# staggered particle bursts as the mass collapses
	for i in 3:
		death_burst.restart()
		death_burst.emitting = true
		EventBus.bus.shake.emit(0.4)
		await _wait(0.35)
	EventBus.bus.boss_died.emit()
	# leave the corpse pile (final death frame) in the arena

func _hitstop(real_seconds: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(real_seconds, true, false, true).timeout
	Engine.time_scale = 1.0

# ---------------------------------------------------------------- helpers

func _spawn_projectile(kind: BossProjectile.Kind, pos: Vector2, vel: Vector2) -> void:
	var scene: PackedScene = load(PROJECTILE_SCENE)
	var proj := scene.instantiate() as BossProjectile
	get_parent().add_child(proj)
	proj.setup(kind, pos, vel)

func _config_particles() -> void:
	slam_dust.emitting = false
	slam_dust.one_shot = true
	slam_dust.amount = 26
	slam_dust.lifetime = 0.55
	slam_dust.explosiveness = 1.0
	slam_dust.local_coords = false
	slam_dust.position = Vector2(0, 44)
	slam_dust.direction = Vector2(0, -1)
	slam_dust.spread = 85.0
	slam_dust.initial_velocity_min = 60.0
	slam_dust.initial_velocity_max = 160.0
	slam_dust.gravity = Vector2(0, 300)
	slam_dust.scale_amount_min = 1.5
	slam_dust.scale_amount_max = 3.0
	slam_dust.color = Color(0.72, 0.62, 0.47)

	charge_dust.emitting = false
	charge_dust.amount = 18
	charge_dust.lifetime = 0.4
	charge_dust.local_coords = false
	charge_dust.position = Vector2(0, 40)
	charge_dust.direction = Vector2(0, -1)
	charge_dust.spread = 40.0
	charge_dust.initial_velocity_min = 30.0
	charge_dust.initial_velocity_max = 70.0
	charge_dust.gravity = Vector2(0, -30)
	charge_dust.scale_amount_min = 1.5
	charge_dust.scale_amount_max = 2.5
	charge_dust.color = Color(0.72, 0.62, 0.47, 0.9)

	summon_swirl.emitting = false
	summon_swirl.one_shot = true
	summon_swirl.amount = 20
	summon_swirl.lifetime = 0.7
	summon_swirl.explosiveness = 0.8
	summon_swirl.local_coords = false
	summon_swirl.spread = 180.0
	summon_swirl.initial_velocity_min = 40.0
	summon_swirl.initial_velocity_max = 90.0
	summon_swirl.gravity = Vector2(0, -140)
	summon_swirl.scale_amount_min = 1.0
	summon_swirl.scale_amount_max = 2.0
	summon_swirl.color = Color(0.8, 0.25, 0.3)

	stun_stars.emitting = false
	stun_stars.amount = 8
	stun_stars.lifetime = 0.8
	stun_stars.local_coords = false
	stun_stars.position = Vector2(0, -46)
	stun_stars.direction = Vector2(0, -1)
	stun_stars.spread = 70.0
	stun_stars.initial_velocity_min = 20.0
	stun_stars.initial_velocity_max = 50.0
	stun_stars.gravity = Vector2(0, -10)
	stun_stars.scale_amount_min = 1.5
	stun_stars.scale_amount_max = 2.5
	stun_stars.color = Color(1.0, 0.85, 0.3)

	death_burst.emitting = false
	death_burst.one_shot = true
	death_burst.amount = 40
	death_burst.lifetime = 0.8
	death_burst.explosiveness = 1.0
	death_burst.local_coords = false
	death_burst.spread = 180.0
	death_burst.initial_velocity_min = 60.0
	death_burst.initial_velocity_max = 220.0
	death_burst.gravity = Vector2(0, 260)
	death_burst.scale_amount_min = 1.5
	death_burst.scale_amount_max = 3.5
	death_burst.color = Color(0.62, 0.14, 0.16)
