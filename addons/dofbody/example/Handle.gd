class_name Handle
extends GrabbableBody

signal grabbed(grabber)
signal released()

func _ready():
	super._ready()
	freeze = true;
	
func grab(grabber: Node3D):
	super.grab(grabber);
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	emit_signal("grabbed", grabber);

func release():
	super.release()
	freeze = true;
	emit_signal("released");
