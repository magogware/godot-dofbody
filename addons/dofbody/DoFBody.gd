extends AnimatableBody3D
class_name DoFBody

signal tick(dof_index);
signal opened(dof_index);
signal closed(dof_index);
signal moving(dof_index);

@export var dofs: Array[DoF]; # (Array, Resource)

enum DoFStatus {
	OPEN,
	CLOSED,
	MOVING
}

var _start: Transform3D;
var _holder: Node3D = null;
#var _holder_transform_at_grab: Transform3D;
var force_excesses: Dictionary
var open_percentage: Dictionary
var close_percentage: Dictionary

var new_transform: Transform3D
var _prev_angles: Vector3
var _dof_status: Dictionary

var _delta: float

var hasbeenheld := false

func _ready():
	_start = global_transform
	for dof in dofs:
		force_excesses[dof] = 0.0
		open_percentage[dof] = 0.0
		close_percentage[dof] = 0.0
	for dof in dofs:
		_dof_status[dof] = DoFStatus.MOVING
	
func _physics_process(delta):
	_delta = delta
	if _holder != null:
		hasbeenheld = true
		var translation: Vector3 = dofs.filter(func(dof): return dof.mode == DoF.DoFMode.TRANSLATION).reduce(_calculate_translation, Vector3.ZERO)
		new_transform = _start.translated_local(translation)
		dofs.filter(func(dof): return dof.mode == DoF.DoFMode.ROTATION).map(_calculate_and_apply_rotation)
		# TODO: Detect status change, store it, and emit it
		# TODO: Emit ticks
		global_transform = new_transform
	else:
		if (hasbeenheld):
			var translation: Vector3 = dofs.filter(func(dof): return dof.mode == DoF.DoFMode.TRANSLATION && dof.retract_mode != DoF.RetractMode.NO_RETRACT).reduce(_calculate_translation_retraction, _start.inverse() * global_position)
			new_transform = _start.translated_local(translation)
			dofs.filter(func(dof): return dof.mode == DoF.DoFMode.ROTATION && dof.retract_mode != DoF.RetractMode.NO_RETRACT).map(_calculate_and_apply_rotation_retraction)
			global_transform = new_transform
			# FIXME: rotation retraction doesn't work, just resets to zero. Likely something to do with translating from _start or setting rotation to 0 because of some weird accumulation thing I haven't caught

func _calculate_translation(accum: Vector3, dof: DoF) -> Vector3:
	var holder_origin_localised: Vector3 = _start.inverse() * _holder.global_transform.origin
	var axial_displacement: float = holder_origin_localised[dof.primary_axis]
	
	var global_origin_localised: Vector3 = _start.inverse() * global_position
	var bounds: Vector2 = _calculate_bounds(global_origin_localised[dof.primary_axis], axial_displacement, dof)
	
	accum[dof.primary_axis] = clampf(axial_displacement, bounds[0], bounds[1]);
	return accum;
	
func _calculate_translation_retraction(accum: Vector3, dof: DoF) -> Vector3:
	var axial_displacement: float = (_start.inverse() * global_position)[dof.primary_axis] + (dof.retract_speed if dof.retract_mode == DoF.RetractMode.RETRACTS_OPEN else -dof.retract_speed)
	
	var global_origin_localised: Vector3 = _start.inverse() * global_position
	var bounds: Vector2 = _calculate_bounds(global_origin_localised[dof.primary_axis], axial_displacement, dof)
	
	accum[dof.primary_axis] = clampf(axial_displacement, bounds[0], bounds[1]);
	return accum;
	
func _calculate_and_apply_rotation(dof: DoF) -> void:
	# Linked rotation works best if facing, more robust calculation would need to include code on grabber's linked axis' angular displacement from its start, which needs additional programming and puts code for the DoFBody outside of the dofbody
	# maybe something to implement with an interface and a component node?
	var holder_origin_localised: Vector3 = new_transform.inverse() * (_holder.global_position if !dof.rotation_linked_to_controller else new_transform.origin + _holder.global_transform.basis[dof.linked_axis])
	var primary_axis_localised: Vector3 = new_transform.basis.inverse() * (new_transform.basis[dof.primary_axis])
	var secondary_axis_localised: Vector3 = new_transform.basis.inverse() * (new_transform.basis[dof.secondary_axis])
	var axial_displacement: float = secondary_axis_localised.signed_angle_to(holder_origin_localised, primary_axis_localised)
	
	var bounds: Vector2 = _calculate_bounds(_prev_angles[dof.primary_axis], axial_displacement, dof)
	var clamped_axial_displacement: float = clamp(axial_displacement, -dof.close_rom, dof.open_rom)
	_prev_angles[dof.primary_axis] = clamped_axial_displacement
	
	new_transform = new_transform.rotated_local(primary_axis_localised, clamped_axial_displacement) # BUG: this doesn't work and continuously rotates if done on the global transform , whereas using an intermediate variable doesn't
	
func _calculate_and_apply_rotation_retraction(dof: DoF) -> void:
	# Linked rotation works best if facing, more robust calculation would need to include code on grabber's linked axis' angular displacement from its start, which needs additional programming and puts code for the DoFBody outside of the dofbody
	# maybe something to implement with an interface and a component node?
	var primary_axis_localised: Vector3 = new_transform.basis.inverse() * (new_transform.basis[dof.primary_axis])
	var secondary_axis_localised: Vector3 = new_transform.basis.inverse() * (new_transform.basis[dof.secondary_axis])
	var axial_displacement: float = secondary_axis_localised.signed_angle_to(secondary_axis_localised.rotated(primary_axis_localised, dof.retract_speed if dof.retract_mode == DoF.RetractMode.RETRACTS_OPEN else -dof.retract_speed), primary_axis_localised)
	
	var bounds: Vector2 = _calculate_bounds(_prev_angles[dof.primary_axis], axial_displacement, dof)
	var clamped_axial_displacement: float = clamp(axial_displacement, -dof.close_rom, dof.open_rom)
	_prev_angles[dof.primary_axis] = clamped_axial_displacement
	
	new_transform = new_transform.rotated_local(primary_axis_localised, clamped_axial_displacement) # BUG: this doesn't work and continuously rotates if done on the global transform , whereas using an intermediate variable doesn't

func _calculate_bounds(prev_axial_displacement: float, axial_displacement: float, dof: DoF) -> Vector2:
	var upper_bound_speed: float = prev_axial_displacement+(dof.max_open_speed*_delta) if dof.max_open_speed > 0 else INF
	var upper_bound_rom: float = dof.open_rom
	var lower_bound_speed: float = prev_axial_displacement-(dof.max_close_speed*_delta) if dof.max_close_speed > 0 else -INF
	var lower_bound_rom: float = -dof.close_rom
	
	var within_open_latch_angle: bool = _dof_status[dof] == DoFStatus.OPEN and ((axial_displacement + dof.latch_dist >= dof.open_rom and dof.open_latch_mode == DoF.LatchMode.LATCH_WITHIN_DIST) or dof.open_latch_mode == DoF.LatchMode.LATCH_FOREVER)
	var lower_bound_latch = dof.open_rom if within_open_latch_angle else -dof.close_rom
	var within_close_latch_angle: bool = _dof_status[dof] == DoFStatus.CLOSED and ((axial_displacement - dof.latch_dist <= dof.close_rom and dof.close_latch_mode == DoF.LatchMode.LATCH_WITHIN_DIST) or dof.close_latch_mode == DoF.LatchMode.LATCH_FOREVER)
	var upper_bound_latch = -dof.close_rom if within_close_latch_angle else dof.open_rom
	
	return Vector2(max(lower_bound_rom, lower_bound_speed, lower_bound_latch), min(upper_bound_rom, upper_bound_speed, upper_bound_latch))

func _grabbed(holder: Node3D):
	_holder = holder;
#	_holder_transform_at_grab = _holder.global_transform

func _released():
	_holder = null;

