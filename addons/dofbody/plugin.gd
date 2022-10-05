tool
extends EditorPlugin

func _enter_tree():
	add_custom_type("DoFBody", "RigidBody", load("res://addons/dofbody/DoFBody.gd"), load("res://RigidBody3D.svg"))


func _exit_tree():
	remove_custom_type("DoFBody")
