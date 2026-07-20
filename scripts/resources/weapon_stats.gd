class_name WeaponStats
extends Resource
## Data-driven weapon definition. Swapping this resource on a
## WeaponComponent is how upgrades work.

@export var display_name: String = "PISTOL"
@export var fire_cooldown: float = 0.18
@export var bullet_count: int = 1
@export var spread_degrees: float = 0.0
@export var bullet_speed: float = 420.0
@export var bullet_range: float = 260.0
@export var damage: int = 1
@export var knockback: float = 90.0
@export var bullet_modulate: Color = Color(1.0, 0.92, 0.35)
@export var weapon_texture: Texture2D
@export var shoot_sfx: AudioStream
@export var shake: float = 1.0
