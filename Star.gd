extends Sprite2D

var textures = [
	preload("res://assets/pics/star1.png"),
	preload("res://assets/pics/star2.png"),
	preload("res://assets/pics/star2.png"),
	preload("res://assets/pics/star3.png"),
	preload("res://assets/pics/star4.png"),
	preload("res://assets/pics/star4.png"),
]

func _ready():
	self_modulate = Color("#fff", randfn(0.5, 0.15))
	texture = textures.pick_random()
	if not multiplayer.is_server():
		set_physics_process(false)
