extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 7.0
const GRAVITY = 20.0

var rot_x = 0
var camspeed = 0.01

var flying = false

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _physics_process(delta):
	
	if Input.is_action_just_pressed("FlyToggle"):
			flying = !flying
	
	if flying:
		
		var input_dir = Input.get_axis("FlyDown", "FlyUp")
		var direction = (transform.basis * Vector3(0, input_dir, 0)).normalized()
		if direction:
			velocity.y = direction.y * SPEED
		else:
			velocity.y = move_toward(velocity.y, 0, SPEED)
			
	else:
		# Add the gravity.
		if not is_on_floor():
			velocity.y -= GRAVITY * delta

		# Handle Jump.
		if Input.is_action_just_pressed("Jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("MoveLeft", "MoveRight", "MoveForward", "MoveBack")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _input(event):
	if event is InputEventMouseMotion:
		# modify accumulated mouse rotation
		rot_x += event.relative.x * camspeed
		transform.basis = Basis() # reset rotation
		rotate_object_local(Vector3(0, -1, 0), rot_x) # then rotate in X
