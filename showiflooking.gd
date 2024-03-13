extends Node3D

@export var head : Node3D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):

	var headforward = -head.basis.z;
	var aimdirection = position - head.position
	
	#if aimdirection.angle_to(headforward) < 30:
	#	show()
	#else:
	#	hide()

