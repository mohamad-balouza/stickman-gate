extends Node
## Full autonomous playthrough for MCP testing: spawn -> clear enemies
## -> crate -> gaps/pillars -> boss fight -> flag. Frame-based state
## machine driving Input actions; no awaits.

enum Phase { CLEAR, TRAVEL, FIGHT, VICTORY_LAP, DONE }

var player: Player
var boss: Boss
var scene: Node

# scripted route: alternating clear-points and travel segments
var plan := [
	{"clear_kills": 1, "timeout": 900},
	{"to": 560.0, "jumps": [385.0]},
	{"clear_kills": 2, "timeout": 600},
	{"to": 800.0, "jumps": [610.0, 685.0]},
	{"to": 850.0, "jumps": []},
	{"clear_frames": 180},
	{"to": 985.0, "jumps": [862.0]},
	{"clear_kills": 3, "timeout": 700},
	{"to": 1660.0, "jumps": [1080.0, 1408.0, 1560.0]},
	{"clear_kills": 5, "timeout": 800},
	{"to": 2080.0, "jumps": []},
]
var plan_i := 0
var phase := Phase.CLEAR
var frames := 0
var phase_frames := 0
var jump_hold := 0
var dash_cd := 0
var jump_cd := 0
var move_hold := 0
var move_action := ""
var jumps: Array = []
var failed := false

func _ready() -> void:
	scene = get_tree().current_scene
	player = scene.get_node("Player")
	boss = scene.get_node("Boss")
	Input.action_press("shoot")
	_enter_step()

func _exit_tree() -> void:
	_release_all()

func _release_all() -> void:
	for a in ["shoot", "jump", "dash", "move_left", "move_right"]:
		Input.action_release(a)

func _enter_step() -> void:
	phase_frames = 0
	if plan_i >= plan.size():
		phase = Phase.FIGHT
		return
	var step: Dictionary = plan[plan_i]
	if step.has("to"):
		phase = Phase.TRAVEL
		jumps = step["jumps"].duplicate()
		Input.action_press("move_right")
	else:
		phase = Phase.CLEAR
		Input.action_release("move_right")

func _physics_process(_delta: float) -> void:
	if phase == Phase.DONE:
		return
	frames += 1
	phase_frames += 1
	if player.dead or frames > 18000:
		failed = player.dead
		phase = Phase.DONE
		_release_all()
		return
	if jump_hold > 0:
		jump_hold -= 1
		if jump_hold == 0:
			Input.action_release("jump")

	match phase:
		Phase.CLEAR:
			var step: Dictionary = plan[plan_i]
			var goal_kills: int = step.get("clear_kills", -1)
			var t: int = step.get("timeout", step.get("clear_frames", 300))
			if (goal_kills >= 0 and scene.kills >= goal_kills) or phase_frames >= t:
				plan_i += 1
				_enter_step()
		Phase.TRAVEL:
			var step: Dictionary = plan[plan_i]
			if not jumps.is_empty() and player.global_position.x >= jumps[0] and player.is_on_floor():
				jumps.pop_front()
				Input.action_press("jump")
				jump_hold = 22
			if player.global_position.x >= step["to"]:
				Input.action_release("move_right")
				plan_i += 1
				_enter_step()
		Phase.FIGHT:
			_fight()
		Phase.VICTORY_LAP:
			Input.action_press("move_right")
			if scene.state == 2:
				phase = Phase.DONE
				_release_all()

func _fight() -> void:
	if not is_instance_valid(boss) or boss.state == Boss.State.DEAD:
		_release_all()
		Input.action_press("shoot")
		phase = Phase.VICTORY_LAP
		return
	jump_cd = maxi(jump_cd - 1, 0)
	dash_cd = maxi(dash_cd - 1, 0)
	if move_hold > 0:
		move_hold -= 1
		if move_hold == 0 and move_action != "":
			Input.action_release(move_action)
			move_action = ""
		return
	var dx := boss.global_position.x - player.global_position.x
	var adx := absf(dx)
	var toward := 1 if dx > 0.0 else -1
	var charging := absf(boss.velocity.x) > 300.0
	if charging and adx < 160.0 and dash_cd <= 0:
		player.facing = toward
		Input.action_press("dash")
		Input.action_release.call_deferred("dash")
		dash_cd = 45
	elif adx < 110.0:
		_hold("move_left" if toward == 1 else "move_right", 18)
	elif adx > 235.0:
		_hold("move_right" if toward == 1 else "move_left", 10)
	elif player.facing != toward:
		_hold("move_right" if toward == 1 else "move_left", 1)
	if jump_cd <= 0 and player.is_on_floor():
		Input.action_press("jump")
		jump_cd = 55
	elif jump_cd == 40:
		Input.action_release("jump")

func _hold(action: String, time: int) -> void:
	move_action = action
	move_hold = time
	Input.action_press(action)
