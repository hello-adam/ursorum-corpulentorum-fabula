extends Node2D

@onready var hud_menu = $HUD/M/HB/VB/Menu
@onready var console = $HUD/M/HB/ChatConsole
@onready var jc: JamConnect = $JamConnect

@onready var push_up: Area2D = $PushUp
@onready var push_down: Area2D = $PushDown
@onready var push_left: Area2D = $PushLeft
@onready var push_right: Area2D = $PushRight

var the_api_key: String = ""
var game_started = false

func _ready():
	console.jam_connect = jc
	console.visible = false
	hud_menu.get_popup().id_pressed.connect(_on_menu_selection)

func _on_game_time_limit_timeout():
	if jc.server:
		print("Game time limit reached - shutting down...")
		jc.server.shut_down()

var avg_fish_rate = 3
var fish_std_dev = 1
var last_fish: float = 0
var next_fish: float = 0
var counting_down: bool = false:
	set(v):
		counting_down = v
		if multiplayer.is_server():
			set_counting_down.rpc(v)
	
var count_downf: float = 0.0
var count_down: int = 10:
	set(v):
		count_down = v
		if not multiplayer.is_server():
			$HUD/CountDown.text = "%d" % [count_down]
func _process(delta):
	if not multiplayer.is_server() or not game_started:
		return
	
	last_fish += delta
	if (last_fish >= next_fish):
		last_fish = 0
		next_fish = randfn(avg_fish_rate, fish_std_dev)
		var f: RigidBody2D = preload("res://Fish.tscn").instantiate()
		f.rotation = randf_range(0, 2*PI)
		f.position = Vector2()
		f.linear_velocity = Vector2(randfn(150.0, 20.0), 0).rotated(randf_range(0, 2*PI))
		f.angular_velocity = randfn(0.0, 0.5)
		$Fishes.add_child(f, true)
	
	if counting_down:
		count_downf = maxf(0.0, count_downf - delta)
		if ceil(count_downf) != count_down:
			set_count_down.rpc(ceil(count_downf))
			if count_down == 0:
				counting_down = false

@rpc("call_local")
func set_count_down(x: int):
	count_down = x

@rpc
func set_counting_down(x: bool):
	$HUD/CountDown.visible = x

#
# Server actions for player join/leave
#

var all_bears = {}

func _on_jam_connect_player_connected(pid: int, username: String):
	$GameTimeLimit.stop()
	$GameTimeLimit.start(60 * 10)
	
	if not game_started:
		game_started = true
		print("starting phase 1")
		$CountIn.start()
		counting_down = true
		count_downf = $CountIn.wait_time
	
	var bear = preload("res://Bear.tscn").instantiate()
	bear.pid = pid
	bear.player = username
	all_bears[pid] = bear
	position_bears()
	$Bears.add_child(bear, true)

func _on_jam_connect_player_disconnected(pid: int, _username: String):
	var bear = all_bears.get(pid)
	if bear != null:
		bear.queue_free()
		all_bears.erase(pid)
		position_bears()

func position_bears():
	var count: float = len(all_bears.values())
	var pids := all_bears.keys()
	pids.sort()
	var idx := 0.0
	for p in pids:
		idx += 1.0
		var bear = all_bears[p]
		var angle: float = (idx / count) * 2 * PI
		print("bear %d angle: " % [p], angle)
		bear.rotation = angle
		bear.position = Vector2(0, 300).rotated(angle)
		bear.score_multiplier = count * 1.2

#
# HUD interactions
#

func _on_console_pressed():
	console.visible = not console.visible

func _on_menu_selection(id: int):
	if id == 0:
		await jc.client.leave_game()
	elif id == 1:
		if await jc.client.leave_game():
			get_tree().quit(0)
		else:
			get_tree().quit(1)

#
# HUD controls for touchscreen
#

func _on_jam_connect_local_player_joining():
	$HUD.visible = true
	$HUD/TouchControl.visible = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")

func _on_jam_connect_local_player_left():
	for b in $Bears.get_children():
		b.queue_free()
	for f in $Fishes.get_children():
		f.queue_free()
	
	$HUD.visible = false
	$TitleZone/TitleCam.make_current()

func _on_chomp_button_down():
	var e := InputEventAction.new()
	e.action = &"chomp"
	e.pressed = true
	Input.parse_input_event(e)

func _on_chomp_button_up():
	var e := InputEventAction.new()
	e.action = &"chomp"
	e.pressed = false
	Input.parse_input_event(e)

#
# Server API examples
#

func _on_jam_connect_server_post_ready():
	$GameTimeLimit.start(60 * 15)
	
	if jc.server.dev_mode and not jc.server.has_dev_keys:
		return
	
	# Example of fetching project variables in production after the server is in the "ready" state
	var res = await jc.server.callback_api.get_vars(["THE_API_KEY"])
	if res.errored:
		printerr(res.error_msg)
		return
	print(res.data)
	print("fetched API key value: %s" % [res.data["vars"]["THE_API_KEY"]])
	
	# Example of using the data API to read and write persistent data
	res = await jc.server.data_api.get_object("gamestamp")
	var counter = 0
	if res.errored:
		printerr("Failed to get 'gamestamp' - ", res.error_msg)
	else:
		print("Got gamestamp data: ", res.data)
		counter = res.data["counter"] + 1
	
	res = await  jc.server.data_api.put_object("gamestamp", {
		"started": Time.get_datetime_string_from_system(true),
		"message": "this message is for next time",
		"counter": counter # this wouldn't be a precise way to count sessions as there is a potential race condition
	})
	if res.errored:
		printerr("Failed to put 'gamestamp' - ", res.error_msg)

func _on_count_in_timeout():
	print("End of count in")
	$Phase1.start()

func _on_phase_1_timeout():
	print("End of phase 1")
	avg_fish_rate = 1.75
	fish_std_dev = .75
	$Phase2.start()

func _on_phase_2_timeout():
	print("End of phase 2")
	avg_fish_rate = .7
	fish_std_dev = .3
	$CountDown.start()
	count_downf = $CountDown.wait_time
	counting_down = true

func _on_count_down_timeout():
	print("End of count down")
	
	for b in all_bears.values():
		b.set_game_end.rpc()
	
	await get_tree().create_timer(0.5).timeout
	
	var winner
	var high_score: int = 0
	for b in all_bears.values():
		b.set_game_end.rpc()
		if b.score > high_score:
			winner = b
			high_score = b.score
	
	if winner == null:
		set_end_title.rpc("The darkness remains...")
	else:
		set_end_title.rpc("%s has reclaimed celestial glory!\nScore: %d" % [winner.player, high_score])
		add_winners(winner)

func add_winners(winner: Variant):
	print("adding winners")
	
	var res = await jc.server.data_api.get_object("winners")
	var counter = 0
	var winners = {}
	if res.errored:
		printerr("Failed to get 'winners' - ", res.error_msg)
	else:
		print("Got winners data: ", res.data)
		winners = res.data
	
	winners[winner.player] = winner.score
	
	for k in winners.keys():
		add_winner_bear.rpc("%s\n%d" % [k, winners[k]])
	
	res = await jc.server.data_api.put_object("winners", winners)
	if res.errored:
		printerr("Failed to put 'winners' - ", res.error_msg)
	

@rpc
func set_end_title(text: String):
	$HUD/EndTitle.visible = true
	$HUD/EndTitle.text = text


@rpc
func add_winner_bear(text: String):
	var w = preload("res://WinnerBear.tscn").instantiate()
	var bounds = Vector2(get_viewport_rect().size.x / 2.3, get_viewport_rect().size.y / 2.3)
	w.position = Vector2(randf_range(bounds.x * -1, bounds.x), randf_range(bounds.y * -1, bounds.y))
	w.msg = text
	$EndZone.add_child(w, true)
	
