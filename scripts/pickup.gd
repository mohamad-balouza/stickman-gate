extends Area2D
## Weapon upgrade crate. Swaps the WeaponStats resource on the
## player's WeaponComponent — pure composition, no player changes.

@export var new_stats: WeaponStats
@export var toast_text: String = "TRIPLE SHOT!"

@onready var sprite: Sprite2D = $Sprite
@onready var sfx: AudioStreamPlayer2D = $Sfx

var _taken := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	sfx.stream = preload("res://assets/sfx/pickup.wav")
	var tw := create_tween().set_loops()
	tw.tween_property(sprite, "position:y", -3.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(sprite, "position:y", 3.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body: Node2D) -> void:
	if _taken or new_stats == null:
		return
	var player := body as Player
	if player == null:
		return
	_taken = true
	player.weapon.stats = new_stats
	EventBus.bus.weapon_upgraded.emit(new_stats.display_name)
	EventBus.bus.toast.emit(toast_text)
	EventBus.bus.shake.emit(0.3)
	sprite.visible = false
	set_deferred("monitoring", false)
	sfx.play()
	await sfx.finished
	queue_free()
