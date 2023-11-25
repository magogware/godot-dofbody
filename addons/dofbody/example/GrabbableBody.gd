class_name GrabbableBody
extends RigidBody3D

signal interaction_began;

@export var interactable: bool = false;
var holder: Node3D;

func grab(grabber: Node3D):
	holder = grabber;
	freeze = true;
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC; # should not be the case, but how do we move it with it's parent in an extensible way?
	set_process_input(interactable);
	
func release():
	holder = null;
	freeze = false
	set_process_input(false);

func _ready():
	set_process_input(false);
	
func _interact():
	pass;

func _input(event):
	if event.is_action_pressed("interact"):
		emit_signal("interaction_began");
		_interact();
