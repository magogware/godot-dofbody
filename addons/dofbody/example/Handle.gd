class_name Handle
extends GrabbableBody

signal grabbed(grabber)
signal released()
	
func grabbed(grabber: Spatial):
	.grabbed(grabber)
	emit_signal("grabbed", grabber)

func released():
	.released()
	emit_signal("released")
