extends Resource
class_name DoF
tool

enum Axis {
	X,
	Y,
	Z
}

enum RetractMode {
	RETRACTS_CLOSED,
	RETRACTS_OPEN,
	NO_RETRACT
}

enum DoFMode {
	ROTATION,
	TRANSLATION
}

enum LatchMode {
	LATCH_FOREVER,
	LATCH_WITHIN_DIST,
	NEVER_LATCH
}

var mode: int = DoFMode.TRANSLATION;
var primary_axis: int = Axis.X;
var secondary_axis: int;
var linked_axis: int;
var rotation_linked_to_controller: bool = false

var open_rom: float = 0 setget _set_open_rom;
var close_rom: float = 0 setget _set_close_rom;

var retract_mode: int = RetractMode.NO_RETRACT
var retract_speed: float = 0 setget _set_retract_speed;

var max_open_speed: float = 0 setget _set_max_open_speed;
var max_close_speed: float = 0 setget _set_max_close_speed;

var num_ticks: int

var latch_dist: float = 0 setget _set_latch_dist;
var open_latch_mode: int = LatchMode.NEVER_LATCH
var close_latch_mode: int = LatchMode.NEVER_LATCH

func _set_open_rom(val: float):
	if !Engine.editor_hint and mode == DoFMode.ROTATION:
		open_rom = deg2rad(val)
	else:
		open_rom = val
		
func _set_close_rom(val: float):
	if !Engine.editor_hint and mode == DoFMode.ROTATION:
		close_rom = deg2rad(val)
	else:
		close_rom = val
				
func _set_retract_speed(val: float):
	if !Engine.editor_hint and mode == DoFMode.ROTATION:
		retract_speed = deg2rad(val)
	else:
		retract_speed = val

func _set_max_open_speed(val: float):
	if !Engine.editor_hint and mode == DoFMode.ROTATION:
		max_open_speed = deg2rad(val)
	else:
		max_open_speed = val
		
func _set_max_close_speed(val: float):
	if !Engine.editor_hint and mode == DoFMode.ROTATION:
		max_close_speed = deg2rad(val)
	else:
		max_close_speed = val
		
func _set_latch_dist(val: float):
	if !Engine.editor_hint and mode == DoFMode.ROTATION:
		latch_dist = deg2rad(val)
	else:
		latch_dist = val

func _get_property_list() -> Array:
	var properties: Array = []
	properties.append({
		"name": "Mode",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": String(DoFMode.keys()).replace("[", "").replace("]", "")
	})
	var primary_axis_tip := "Translation axis" if mode != DoFMode.ROTATION else "Rotation axis"
	properties.append({
		"name": primary_axis_tip,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": String(Axis.keys()).replace("[", "").replace("]", "")
	})
	if (mode == DoFMode.ROTATION):
		properties.append({
			"name": "Edge axis",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": String(Axis.keys()).replace("[", "").replace("]", "")
		})
		properties.append({
			"name": "Rotation is linked to controller",
			"type": TYPE_BOOL
		})
		if rotation_linked_to_controller:
			properties.append({
				"name": "Linked axis",
				"type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": String(Axis.keys()).replace("[", "").replace("]", "")
			})

	properties.append({
		"name": "Constraints",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_CATEGORY  | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
		"name": "Open range of motion",
		"type": TYPE_REAL,
	})
	properties.append({
		"name": "Close range of motion",
		"type": TYPE_REAL,
	})
	properties.append({
		"name": "Max opening speed",
		"type": TYPE_REAL,
	})
	properties.append({
		"name": "Max closing speed",
		"type": TYPE_REAL,
	})

	properties.append({
		"name": "Retraction",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_CATEGORY  | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
		"name": "Retraction direction",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": String(RetractMode.keys()).replace("[", "").replace("]", "")
	})
	if retract_mode != RetractMode.NO_RETRACT:
		properties.append({
			"name": "Retraction speed",
			"type": TYPE_REAL,
		})

	properties.append({
		"name": "Latching",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_CATEGORY  | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
		"name": "Open latching mode",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": String(LatchMode.keys()).replace("[", "").replace("]", "")
	})
	properties.append({
		"name": "Close latching mode",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": String(LatchMode.keys()).replace("[", "").replace("]", "")
	})
	if close_latch_mode == LatchMode.LATCH_WITHIN_DIST or open_latch_mode == LatchMode.LATCH_WITHIN_DIST:
		properties.append({
			"name": "Latching distance",
			"type": TYPE_REAL,
		})
	properties.append({
		"name": "Number of ticks",
		"type": TYPE_INT,
	})

	return properties

func _set(prop: String, val) -> bool:
	match prop:
		"Mode":
			mode = val
		"Translation axis", "Rotation axis":
			primary_axis = val
		"Edge axis":
			secondary_axis = val
		"Rotation is linked to controller":
			rotation_linked_to_controller = val
		"Linked axis":
			linked_axis = val
		"Open range of motion":
			_set_open_rom(val)
		"Close range of motion":
			_set_close_rom(val)
		"Max opening speed":
			_set_max_open_speed(val)
		"Max closing speed":
			_set_max_close_speed(val)
		"Retraction direction":
			retract_mode = val
		"Retraction speed":
			_set_retract_speed(val)
		"Open latching mode":
			open_latch_mode = val
		"Close latching mode":
			close_latch_mode = val
		"Latching distance":
			_set_latch_dist(val)
		"Number of ticks":
			num_ticks = val
	property_list_changed_notify()
	return true

func _get(prop: String):
	match prop:
		"Mode":
			return mode
		"Translation axis", "Rotation axis":
			return primary_axis
		"Edge axis":
			return secondary_axis
		"Rotation is linked to controller":
			return rotation_linked_to_controller
		"Linked axis":
			return linked_axis
		"Open range of motion":
			return open_rom
		"Close range of motion":
			return close_rom
		"Max opening speed":
			return max_open_speed
		"Max closing speed":
			return max_close_speed
		"Retraction direction":
			return retract_mode
		"Retraction speed":
			return retract_speed
		"Open latching mode":
			return open_latch_mode
		"Close latching mode":
			return close_latch_mode
		"Latching distance":
			return latch_dist
		"Number of ticks":
			return num_ticks
		_:
			return null
