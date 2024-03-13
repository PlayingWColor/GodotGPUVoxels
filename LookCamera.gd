extends Camera3D

@export var aimBlock : MeshInstance3D

var rot_y = 0
var speed = 0.01

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
	#rotate(Vector3(0, 1, 0), 0.1)
	#rotate(Vector3(0, 1, 0), 0.1)
#	pass

func _physics_process(_delta):
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position - get_global_transform().basis.z * 5)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)

	if result:
		var block_pos = ceil(result.position - result.normal * 0.5)
		aimBlock.global_position = block_pos - Vector3.ONE * 0.5
		aimBlock.global_rotation = Vector3(0,0,0)
		
		if Input.is_action_just_pressed("PlaceBlock"):
			_tryeditblock(block_pos+result.normal, 255, result.collider.get_parent())
			
		if Input.is_action_just_pressed("RemoveBlock"):
			_tryeditblock(block_pos, 0, result.collider.get_parent())
	else:
		aimBlock.set_position(Vector3(0,0,0))

func _tryeditblock(point : Vector3, value : int, hitObject : Node):
	print(point)
	if hitObject && hitObject.has_method("_setvalueatpos"):
		hitObject._setvalueatpos(point, value)
			

func _input(event):
	if event is InputEventMouseMotion:
		# modify accumulated mouse rotation
		rot_y += event.relative.y * speed
		transform.basis = Basis() # reset rotation
		rotate_object_local(Vector3(-1, 0, 0), rot_y) # then rotate in X
