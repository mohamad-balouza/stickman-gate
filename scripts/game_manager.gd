extends Node2D
## Level flow: START (paused) -> PLAYING -> WON / DEAD -> restart.
## Owns the kill counter; everything else arrives via EventBus.

enum State { START, PLAYING, WON, DEAD }

@onready var hud: CanvasLayer = $HUD
@onready var win_sfx: AudioStreamPlayer = $HUD/WinSfx
@onready var die_sfx: AudioStreamPlayer = $HUD/DieSfx
@onready var gate_sfx: AudioStreamPlayer = $HUD/GateSfx
@onready var terrain: TileMapLayer = $Terrain

# stone gate columns (tile coords): entry seals the arena on engage,
# exit crumbles open when the boss dies
const ENTRY_GATE_X := [122, 123]
const EXIT_GATE_X := [152, 153]
const GATE_Y_TOP := 15
const GATE_Y_BOTTOM := 19
const STONE_ATLAS := Vector2i(2, 0)

var state := State.START
var kills := 0
var goal := 0

func _ready() -> void:
	goal = get_tree().get_nodes_in_group("enemies").size()
	win_sfx.stream = preload("res://assets/sfx/win.wav")
	die_sfx.stream = preload("res://assets/sfx/player_die.wav")
	gate_sfx.stream = preload("res://assets/sfx/gate_rumble.wav")
	EventBus.bus.enemy_killed.connect(_on_enemy_killed)
	EventBus.bus.player_died.connect(_on_player_died)
	EventBus.bus.level_won.connect(_on_level_won)
	EventBus.bus.boss_engaged.connect(_on_boss_engaged)
	EventBus.bus.boss_died.connect(_on_boss_died)
	hud.start_pressed.connect(_on_start)
	hud.restart_pressed.connect(_on_restart)
	hud.set_kills(0, goal)
	get_tree().paused = true
	hud.show_start()

func _on_start() -> void:
	if state != State.START:
		return
	state = State.PLAYING
	get_tree().paused = false
	hud.hide_panels()

func _on_restart() -> void:
	if state != State.WON and state != State.DEAD:
		return
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_enemy_killed() -> void:
	kills += 1
	hud.set_kills(kills, goal)

func _on_player_died() -> void:
	if state != State.PLAYING:
		return
	state = State.DEAD
	die_sfx.play()
	await get_tree().create_timer(1.2).timeout
	if state != State.DEAD:
		return
	get_tree().paused = true
	hud.show_death()

func _on_boss_engaged(_display_name: String, _max_hp: int) -> void:
	# seal the arena behind the player
	for x in ENTRY_GATE_X:
		for y in range(GATE_Y_TOP, GATE_Y_BOTTOM + 1):
			terrain.set_cell(Vector2i(x, y), 0, STONE_ATLAS)
	gate_sfx.play()
	EventBus.bus.shake.emit(0.5)

func _on_boss_died() -> void:
	await get_tree().create_timer(1.6).timeout
	for gate_x in [ENTRY_GATE_X, EXIT_GATE_X]:
		for x in gate_x:
			for y in range(GATE_Y_TOP, GATE_Y_BOTTOM + 1):
				terrain.erase_cell(Vector2i(x, y))
	_gate_debris(Vector2(2448, 280))
	_gate_debris(Vector2(1968, 280))
	gate_sfx.play()
	EventBus.bus.shake.emit(0.7)
	EventBus.bus.toast.emit("THE GATE HAS CRUMBLED!")

func _gate_debris(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 24
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.position = pos
	p.spread = 180.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 140.0
	p.gravity = Vector2(0, 420)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(0.55, 0.55, 0.63)
	add_child(p)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

func _on_level_won() -> void:
	if state != State.PLAYING:
		return
	state = State.WON
	win_sfx.play()
	EventBus.bus.shake.emit(0.4)
	await get_tree().create_timer(0.6).timeout
	get_tree().paused = true
	hud.show_win(kills, goal)
