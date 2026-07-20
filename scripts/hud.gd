extends CanvasLayer
## In-game HUD plus start/death/win overlays. Runs while the tree is
## paused (process_mode ALWAYS) and forwards start/restart input to
## the GameManager via signals.

signal start_pressed
signal restart_pressed

const HEART_FULL := preload("res://assets/heart_full.png")
const HEART_EMPTY := preload("res://assets/heart_empty.png")

@onready var hearts: Array[TextureRect] = [
	$Root/Hearts/H1, $Root/Hearts/H2, $Root/Hearts/H3,
]
@onready var kills_label: Label = $Root/InfoBox/KillsLabel
@onready var weapon_label: Label = $Root/InfoBox/WeaponLabel
@onready var toast_label: Label = $Root/Toast
@onready var start_panel: Control = $Root/StartPanel
@onready var death_panel: Control = $Root/DeathPanel
@onready var win_panel: Control = $Root/WinPanel
@onready var win_kills_label: Label = $Root/WinPanel/Panel/VBox/KillsResult
@onready var boss_box: VBoxContainer = $Root/BossBox
@onready var boss_name_label: Label = $Root/BossBox/BossName
@onready var boss_bar: ProgressBar = $Root/BossBox/Bar

func _ready() -> void:
	EventBus.bus.player_health_changed.connect(set_health)
	EventBus.bus.weapon_upgraded.connect(set_weapon)
	EventBus.bus.toast.connect(show_toast)
	EventBus.bus.boss_engaged.connect(show_boss_bar)
	EventBus.bus.boss_health_changed.connect(set_boss_health)
	EventBus.bus.boss_died.connect(hide_boss_bar)
	toast_label.visible = false
	boss_box.visible = false
	hide_panels()

func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action_pressed("jump") or event.is_action_pressed("shoot")):
		return
	if start_panel.visible:
		start_pressed.emit()
	elif death_panel.visible or win_panel.visible:
		restart_pressed.emit()

func set_health(hp: int, _max_hp: int) -> void:
	for i in hearts.size():
		hearts[i].texture = HEART_FULL if i < hp else HEART_EMPTY

func set_kills(kills: int, goal: int) -> void:
	kills_label.text = "KILLS %d/%d" % [kills, goal]

func set_weapon(display_name: String) -> void:
	weapon_label.text = display_name

func show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_label.modulate.a = 0.0
	toast_label.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(toast_label, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(toast_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void: toast_label.visible = false)

func show_boss_bar(display_name: String, max_hp: int) -> void:
	boss_name_label.text = display_name
	boss_bar.max_value = max_hp
	boss_bar.value = max_hp
	boss_box.visible = true
	boss_box.modulate.a = 0.0
	create_tween().tween_property(boss_box, "modulate:a", 1.0, 0.5)

func set_boss_health(hp: int, _max_hp: int) -> void:
	boss_bar.value = hp

func hide_boss_bar() -> void:
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(boss_box, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func() -> void: boss_box.visible = false)

func show_start() -> void:
	hide_panels()
	start_panel.visible = true

func show_death() -> void:
	hide_panels()
	death_panel.visible = true

func show_win(kills: int, goal: int) -> void:
	hide_panels()
	win_kills_label.text = "STICKMEN DEFEATED: %d/%d" % [kills, goal]
	win_panel.visible = true

func hide_panels() -> void:
	start_panel.visible = false
	death_panel.visible = false
	win_panel.visible = false
