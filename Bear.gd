extends Node2D

@onready var head: Node2D = $Head
@onready var sprite: AnimatedSprite2D = $Head/Sprite
@onready var mouth: Area2D = $Head/Mouth
@onready var cam: Camera2D = $Head/Camera2D

@onready var torso: Node2D = $Torso

var eating: bool = false:
	set(v):
		eating = v
		if sprite:
			if v:
				sprite.animation = &"eating"
			else:
				sprite.animation = &"default"

var reaching: bool = false
var score_multiplier = 1.0
var pid: int = 1
var active: bool = true:
	set(v):
		if not v and multiplayer.get_unique_id() == pid:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

@rpc
func set_game_end():
	active = false
	get_node("../../EndZone/EndCam").make_current()

var score_label: Label

var score: float = 0:
	set(v):
		if score == v:
			return
		var diff = v - score
		score = v
		if not multiplayer.is_server():
			if score_label:
				score_label.text = "Score: %d" % [round(v)]
			for _x in range(floor(diff)):
				var star = preload("res://Star.tscn").instantiate()
				star.position = Vector2(randfn(0, 25.0 + (score / 5)), randfn(0, 35.0 + (score / 50)))
				torso.add_child(star)
				var star2 = preload("res://Star.tscn").instantiate()
				star2.position = Vector2(randfn(0, 25.0 + (score / 5)), randfn(0, 35.0 + (score / 50)))
				torso.add_child(star2)
			
var player: String = "":
	set(v):
		player = v
		$Head/NameTag.text = v

var sprite_animation: String:
	get:
		return sprite.animation
	set(v):
		sprite.animation = v

var head_position: Vector2:
	get:
		return $Head.position
	set(v):
		$Head.position = v

var claws_position: Vector2:
	get:
		return $Claws.position
	set(v):
		$Claws.position = v

func _ready():
	if multiplayer.get_unique_id() == pid:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		cam.make_current()
		
		score_label = get_node("../../HUD/Score")
		score = 0
	
	eating = eating
	

const CLAW_SPEED = 8.0
var claws_target_x = 0.0
func _process(delta):
	if multiplayer.is_server():
		claws_position = $Claws.position.lerp(Vector2(claws_target_x, (head_position.y / 2.0) + 25), delta * CLAW_SPEED)

func _input(event):
	if multiplayer.get_unique_id() != pid or not active:
		return
	
	if event is InputEventMouseMotion:
		if absf(event.relative.x) > 5.0:
			var new_x = clampf(claws_target_x + (event.relative.x / 4.0), -50, 50)
			if new_x != claws_target_x:
				claws_target_x = new_x
				set_claws_target.rpc_id(1, claws_target_x)
	
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event):
	if multiplayer.get_unique_id() != pid or not active:
		return
	
	if event is InputEventMouseButton:
		if event.pressed:
			if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if event.is_action_pressed(&"chomp"):
		if multiplayer.is_server():
			await set_eating()
		else:
			set_eating.rpc_id(1)
	elif event.is_action_released(&"chomp"):
		if multiplayer.is_server():
			await reach_chomp()
		else:
			reach_chomp.rpc_id(1)

@rpc("any_peer", "reliable")
func set_claws_target(x: float):
	if not multiplayer.is_server() or pid != multiplayer.get_remote_sender_id():
		return
	claws_target_x = x

@rpc("any_peer", "reliable")
func set_eating():
	if not multiplayer.is_server() or pid != multiplayer.get_remote_sender_id():
		return
	
	if eating or reaching:
		return
	
	eating = true

@rpc("any_peer", "reliable")
func reach_chomp():
	if not multiplayer.is_server() or pid != multiplayer.get_remote_sender_id():
		return
	
	if reaching:
		return
	if not eating:
		return
	
	reaching = true
	
	var reach_tween = get_tree().create_tween()
	reach_tween.tween_property(self, "head_position", Vector2(0, -250), 0.5)
	reach_tween.play()
	await reach_tween.finished
	
	eating = false
	
	var return_tween = get_tree().create_tween()
	return_tween.tween_property(self, "head_position", Vector2(0, 0), 0.75)
	return_tween.play()
	await return_tween.finished

	reaching = false


func _on_mouth_body_entered(body):
	if not multiplayer.is_server():
		return
		
	if not eating:
		return
	
	if body.is_in_group("fish"):
		body.queue_free()
		score += score_multiplier
