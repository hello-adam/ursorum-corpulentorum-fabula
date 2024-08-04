extends Node2D

var msg: String = "":
	set(v):
		msg = v
		if $Msg:
			$Msg.text = msg

# Called when the node enters the scene tree for the first time.
func _ready():
	$Stars.rotation = randf_range(PI / -3, PI / 3)
	msg = msg

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
