extends KinematicBody

const GRAVITY_ALIGNMENT_SPEED = 10.0

export var move_speed = 1.0
export var move_air_speed = 0.05
export var jump_speed = 5.0
export var linear_velocity = Vector3()
export var angular_velocity = Vector3()
export var look_sensitivity = Vector2(360.0, 360.0)

# we set this to true, so if you start off the floor
# you can't jump right away
var has_jumped = true
onready var camera = $Camera

func _physics_process(delta):
	
	# When transforming a kinematic body
	# state.linear_velocity, and state.angular_velocity will change
	var state = PhysicsServer.body_get_direct_state(get_rid())
	
	# Apply linear and angular damping
	angular_velocity -= angular_velocity * state.total_angular_damp * delta
	linear_velocity -= linear_velocity * state.total_linear_damp * delta
	
	align_to_gravity(state)
	stick_to_floor(state)
	handle_movement(state)
	
	linear_velocity = move_and_slide(linear_velocity, -state.total_gravity.normalized())
	global_transform.basis = Basis(Quat(global_transform.basis) * Quat(angular_velocity * delta))
	
	if is_on_floor():
		# simulate friction
		linear_velocity *= 0.9

func stick_to_floor(state:PhysicsDirectBodyState):
	if is_on_floor():
		linear_velocity = linear_velocity.slerp(linear_velocity.slide(state.total_gravity.normalized()), state.step)
		

func align_to_gravity(state:PhysicsDirectBodyState):
	var gravity_up = -state.total_gravity.normalized()
	
	if gravity_up:
		# Make gravity_up relative to our rotation
		gravity_up = global_transform.basis.xform_inv(gravity_up)
		# The cross product will tell us how much of a rotation we need
		# To align with gravity
		var change = Quat(Vector3.UP.cross(gravity_up))
		var q = Quat(global_transform.basis)
		
		# Covert the Quaternion back into a basis, so it can be used as our rotation
		global_transform.basis = Basis(q.slerpni(q * change, GRAVITY_ALIGNMENT_SPEED * state.step))

func handle_movement(state:PhysicsDirectBodyState):
	
	var move = Vector3()
	move.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	move.z = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	
	if is_on_floor():
		has_jumped = false
		move *= move_speed
	else:
		move *= move_air_speed
	
	# move relative to your rotation, not accounting for the tilt of the camera
	linear_velocity += global_transform.basis.xform(move)
	
	if not has_jumped and Input.is_action_pressed("jump"):
		var strength = Input.get_action_strength("jump")
		linear_velocity -= state.total_gravity * state.step
		linear_velocity += global_transform.basis.xform(Vector3.UP) * jump_speed * strength
		has_jumped = true
	
	linear_velocity += state.total_gravity * state.step
	
func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var look = (event.relative / 15.0)
		
		var delta = get_physics_process_delta_time()
		camera.rotation_degrees.x -= look.y * deg2rad(look_sensitivity.y)
		camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, -90, 90)
		transform.basis = transform.basis.rotated(transform.basis.xform(Vector3.UP), -look.x * deg2rad(look_sensitivity.x) * delta)
