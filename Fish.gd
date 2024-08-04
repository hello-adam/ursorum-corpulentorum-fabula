extends RigidBody2D

var textures = [
	preload("res://assets/pics/fish1.png"),
	preload("res://assets/pics/fish2.png"),
	preload("res://assets/pics/fish3.png")
]

func _ready():
	$Sprite2D.texture = textures.pick_random()
	if not multiplayer.is_server():
		set_physics_process(false)


var swimming: bool = false
func _physics_process(delta):
	if not multiplayer.is_server():
		return
	
	if self.linear_velocity.length() < 35:
		swimming = true
	
	if swimming:
		self.add_constant_central_force(Vector2(0, 250))
		if self.linear_velocity.length() > 180:
			swimming = false
	


func _on_timer_timeout():
	self.queue_free()
