class_name WeaponComponent
extends Node2D
## Fires bullets from the shared BulletPool using a swappable
## WeaponStats resource. Handles cooldown, spread fan, muzzle flash,
## recoil nudge, sound, and screen shake.

signal fired

@export var stats: WeaponStats: set = set_stats

@onready var weapon_sprite: Sprite2D = $WeaponSprite
@onready var muzzle: Marker2D = $Muzzle
@onready var muzzle_flash: Sprite2D = $MuzzleFlash
@onready var shoot_sfx: AudioStreamPlayer2D = $ShootSfx

var _cooldown := 0.0
var _flash_left := 0.0
var _base_sprite_x := 0.0
var _pool: Node = null

func _ready() -> void:
	_base_sprite_x = weapon_sprite.position.x
	if stats == null:
		stats = load("res://resources/weapons/pistol.tres")
	else:
		set_stats(stats)

func set_stats(value: WeaponStats) -> void:
	stats = value
	if not is_node_ready() or stats == null:
		return
	weapon_sprite.texture = stats.weapon_texture
	shoot_sfx.stream = stats.shoot_sfx

func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			muzzle_flash.visible = false
	weapon_sprite.position.x = move_toward(weapon_sprite.position.x, _base_sprite_x, 40.0 * delta)

func try_fire(dir: Vector2) -> bool:
	if stats == null or _cooldown > 0.0:
		return false
	var pool := _get_pool()
	if pool == null:
		return false
	_cooldown = stats.fire_cooldown
	var count := stats.bullet_count
	var total := deg_to_rad(stats.spread_degrees)
	for i in count:
		var t := 0.0 if count <= 1 else (float(i) / float(count - 1)) - 0.5
		pool.fire(muzzle.global_position, dir.rotated(total * t), stats)
	muzzle_flash.visible = true
	_flash_left = 0.06
	weapon_sprite.position.x = _base_sprite_x - 3.0
	if shoot_sfx.stream != null:
		shoot_sfx.pitch_scale = randf_range(0.95, 1.08)
		shoot_sfx.play()
	EventBus.bus.shake.emit(stats.shake * 0.15)
	fired.emit()
	return true

func _get_pool() -> Node:
	if _pool == null or not is_instance_valid(_pool):
		var nodes := get_tree().get_nodes_in_group("bullet_pool")
		_pool = nodes[0] if not nodes.is_empty() else null
	return _pool
