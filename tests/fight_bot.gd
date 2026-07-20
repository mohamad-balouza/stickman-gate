extends Node
## Autonomous boss-fight bot for MCP testing. Added to the running
## scene by game_eval; drives the player via Input actions each
## physics frame — no awaits, so it survives across eval calls.

var player: Player
var boss: Boss
var frames := 0
var done := false
var jump_cd := 0
var dash_cd := 0
var move_hold := 0
var move_action := ""

func _ready() -> void:
	var scene := get_tree().current_scene
	player = scene.get_node("Player")
	boss = scene.get_node("Boss")
	Input.action_press("shoot")

func _exit_tree() -> void:
	for a in ["shoot", "jump", "dash", "move_left", "move_right"]:
		Input.action_release(a)

func _physics_process(_delta: float) -> void:
	if done:
		return
	frames += 1
	if player.dead or frames > 10800:
		done = true
		for a in ["shoot", "jump", "dash", "move_left", "move_right"]:
			Input.action_release(a)
		return
	if not is_instance_valid(boss) or boss.state == Boss.State.DEAD:
		# victory: march to the flag
		for a in ["shoot", "jump", "dash", "move_left"]:
			Input.action_release(a)
		Input.action_press("move_right")
		if get_tree().current_scene.state == 2:
			done = true
			Input.action_release("move_right")
		return

	jump_cd = maxi(jump_cd - 1, 0)
	dash_cd = maxi(dash_cd - 1, 0)

	var dx := boss.global_position.x - player.global_position.x
	var adx := absf(dx)
	var toward := 1 if dx > 0.0 else -1
	var charging := absf(boss.velocity.x) > 300.0

	# finish any timed reposition first
	if move_hold > 0:
		move_hold -= 1
		if move_hold == 0 and move_action != "":
			Input.action_release(move_action)
			move_action = ""
	elif charging and adx < 160.0 and dash_cd <= 0:
		# dash through the charge using dash i-frames
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

	# periodic hop dodges ground shockwaves
	if jump_cd <= 0 and player.is_on_floor():
		Input.action_press("jump")
		jump_cd = 55
	elif jump_cd == 40:
		Input.action_release("jump")

func _hold(action: String, time: int) -> void:
	move_action = action
	move_hold = time
	Input.action_press(action)
