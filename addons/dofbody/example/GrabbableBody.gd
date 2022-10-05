class_name GrabbableBody
extends RigidBody

signal interaction_began

export(bool) var interactable: bool = false
var holder: Spatial

func grabbed(grabber: Spatial):
	holder = grabber
	mode = RigidBody.MODE_KINEMATIC
	set_process_input(interactable)
	
func released():
	holder = null
	mode = RigidBody.MODE_RIGID
	set_process_input(false)

func _ready():
	set_process_input(false)
	
func _interact():
	pass

func _input(event):
	if event.is_action_pressed("interact"):
		emit_signal("interaction_began")
		_interact()
