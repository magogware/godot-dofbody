extends KinematicBody

var vel = Vector3()
var dir = Vector3()

var held_object: GrabbableBody = null
var rotating := 0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	_process_input(delta)
	_process_movement(delta)
	if held_object != null:
		_process_object()
	$RotationHelper/RightHandPos.rotate_z((PI/8)*delta*float(rotating))

func _process_input(delta):
	dir = Vector3()
	var cam_xform = $RotationHelper/Camera.get_global_transform()

	var input_movement_vector = Vector2()
	if Input.is_physical_key_pressed(KEY_W):
		input_movement_vector.y += 1
	if Input.is_physical_key_pressed(KEY_S):
		input_movement_vector.y -= 1
	if Input.is_physical_key_pressed(KEY_A):
		input_movement_vector.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		input_movement_vector.x += 1
	input_movement_vector = input_movement_vector.normalized()
	dir += -cam_xform.basis.z * input_movement_vector.y
	dir += cam_xform.basis.x * input_movement_vector.x

	# if is_on_floor():
	# 	if Input.is_action_just_pressed("jump"):
	# 		vel.y = 18

func _process_movement(delta):
	dir.y = 0
	dir = dir.normalized()

	vel.y += delta * -24.8

	var hvel = vel
	hvel.y = 0

	var target = dir
	target *= 20

	var accel
	if dir.dot(hvel) > 0:
		accel = 4.5
	else:
		accel = 16

	hvel = hvel.linear_interpolate(target, accel * delta)
	vel.x = hvel.x
	vel.z = hvel.z
	vel = move_and_slide(vel, Vector3(0, 1, 0), 0.05, 4, deg2rad(40))

func _process_object():
	pass
#	if !held_object is Handle:
#		var held_scale = held_object.scale
#		held_object.global_transform = $RotationHelper/RightHand.global_transform
#		held_object.scale = held_scale
	#held_object.velocity = vel

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		$RotationHelper.rotate_x(deg2rad(event.relative.y * 0.05 * -1))
		self.rotate_y(deg2rad(event.relative.x * 0.05 * -1))

		var camera_rot = $RotationHelper.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -70, 70)
		$RotationHelper.rotation_degrees = camera_rot
	elif Input.is_physical_key_pressed(KEY_ESCAPE):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif Input.is_mouse_button_pressed(BUTTON_LEFT) and !held_object:
		var bodies_in_zone = $RotationHelper/GrabZone.get_overlapping_bodies()
		if bodies_in_zone.size() > 0:
			_grab_body(bodies_in_zone)
	elif held_object and !Input.is_mouse_button_pressed(BUTTON_LEFT):
		_drop_body()
	elif Input.is_physical_key_pressed(KEY_E):
		rotating = -1;
	elif Input.is_physical_key_pressed(KEY_Q):
		rotating = 1;
	elif !Input.is_physical_key_pressed(KEY_E) and !Input.is_physical_key_pressed(KEY_Q):
		rotating = 0;
		
func _grab_body(bodies_in_zone):
	var grabbed_body
	for body in bodies_in_zone:
		if body is GrabbableBody:
			held_object = body
			held_object.grabbed($RotationHelper/RightHandPos)
			break
			
func _drop_body():
	held_object.released()
#	elif held_object is Handle:
#		held_object.released(global_controller_velocity)
#	else:
	held_object.apply_impulse(Vector3(0,0,0), -$RotationHelper/Camera.global_transform.basis.z)
	
	held_object = null
