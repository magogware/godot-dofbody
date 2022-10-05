extends RigidBody
class_name DoFBody

signal tick(dof_index);
signal opened(dof_index);
signal closed(dof_index);
signal moving(dof_index);

export(Array, Resource) var dofs: Array;

enum DoFStatus {
	OPEN,
	CLOSED,
	MOVING
}

var _start: Transform;
var _holder: Spatial;
var _prior_rotations: Vector3;
#var _holder_transform_at_grab: Transform;
var force_excesses: Dictionary
var open_percentage: Dictionary
var close_percentage: Dictionary

func _ready():
	_start = global_transform
	for dof_resource in dofs:
		var dof: DoF = dof_resource as DoF
		force_excesses[dof] = 0.0
		open_percentage[dof] = 0.0
		close_percentage[dof] = 0.0
	
func _physics_process(delta):
	if _holder != null:
		var total_displacement: Vector3 = Vector3.ZERO
		for i in len(dofs):
			var dof: DoF = dofs[i] as DoF
			if dof.mode == DoF.DoFMode.TRANSLATION:
				var translation_basis: Vector3 = _start.basis.xform_inv(_start.basis[dof.primary_axis])
				var body_axial_displacement: float = _start.xform_inv(global_transform.origin).project(translation_basis)[dof.primary_axis]
				var holder_axial_displacement: float = _start.xform_inv(_holder.global_transform.origin).project(translation_basis)[dof.primary_axis]
				
				holder_axial_displacement = _latch_within_dist(body_axial_displacement, holder_axial_displacement, dof.open_rom, dof.latch_dist, dof.open_latch_mode)
				holder_axial_displacement = _latch_within_dist(body_axial_displacement, holder_axial_displacement, dof.close_rom, dof.latch_dist, dof.close_latch_mode)
				holder_axial_displacement = _limit_speed(body_axial_displacement, holder_axial_displacement, dof.max_open_speed, dof.max_close_speed, delta, dof)
				holder_axial_displacement = _limit_max_rom(body_axial_displacement, holder_axial_displacement, dof.close_rom, dof.open_rom, i) # BUG: 'moving' signal emits constantly
				
				_emit_ticks(body_axial_displacement, holder_axial_displacement, dof.close_rom, dof.open_rom, dof.num_ticks, i)		# BUG: ticks emit constantly at max rom
				
				if dof.open_rom > 0:
					open_percentage[dof] = clamp_with_result(holder_axial_displacement, -dof.close_rom, 0).overflow / dof.open_rom
				if dof.close_rom > 0:
					close_percentage[dof] = clamp_with_result(holder_axial_displacement, 0, dof.open_rom).overflow / dof.close_rom
				total_displacement[dof.primary_axis] += holder_axial_displacement
		global_transform = _start.translated(total_displacement)

		for i in len(dofs):
			var dof: DoF = dofs[i] as DoF
			if dof.mode == DoF.DoFMode.ROTATION:
				var rotation_basis: Vector3 = global_transform.basis[dof.primary_axis]
				var rotation_plane: Plane = Plane(rotation_basis, 0)
				var rotation_axis: Vector3 = global_transform.basis.xform_inv(global_transform.basis[dof.primary_axis])
				var edge_axis: Vector3 = global_transform.basis.xform_inv(global_transform.basis[dof.secondary_axis])
				var holder_axial_rotation: float
				if dof.rotation_linked_to_controller:
					var holder_axis: Vector3 = rotation_plane.project(_holder.global_transform.basis[dof.linked_axis])
					edge_axis = global_transform.basis[dof.secondary_axis]
					holder_axial_rotation = edge_axis.signed_angle_to(holder_axis, rotation_basis)
				else:
					var holder_displacement: Vector3 = global_transform.xform_inv(_holder.global_transform.origin)
					holder_displacement[dof.primary_axis] = 0
					holder_axial_rotation = edge_axis.signed_angle_to(holder_displacement, rotation_axis)
				
				holder_axial_rotation = _latch_within_dist(_prior_rotations[dof.primary_axis], holder_axial_rotation, dof.open_rom, dof.latch_dist, dof.open_latch_mode)
				holder_axial_rotation = _latch_within_dist(_prior_rotations[dof.primary_axis], holder_axial_rotation, dof.close_rom, dof.latch_dist, dof.close_latch_mode)
				holder_axial_rotation = _limit_speed(_prior_rotations[dof.primary_axis], holder_axial_rotation, dof.max_open_speed, dof.max_close_speed, delta, dof)
				holder_axial_rotation = _limit_max_rom(_prior_rotations[dof.primary_axis], holder_axial_rotation, dof.close_rom, dof.open_rom, i)
				
				_emit_ticks(_prior_rotations[dof.primary_axis], holder_axial_rotation, dof.close_rom, dof.open_rom, dof.num_ticks, i)

				_prior_rotations[dof.primary_axis] = holder_axial_rotation
				if dof.open_rom > 0:
					open_percentage[dof] = clamp_with_result(holder_axial_rotation, -dof.close_rom, 0).overflow / dof.open_rom
				if dof.close_rom > 0:
					close_percentage[dof] = clamp_with_result(holder_axial_rotation, 0, dof.open_rom).overflow / dof.close_rom
				global_transform.basis = global_transform.basis.rotated(rotation_basis, holder_axial_rotation)
				
	else:
		var total_displacement: Vector3 = Vector3.ZERO
		for i in len(dofs):
			var dof: DoF = dofs[i] as DoF
			if dof.mode == DoF.DoFMode.TRANSLATION:
				var translation_basis: Vector3 = _start.basis.xform_inv(_start.basis[dof.primary_axis])
				var body_axial_displacement: float = _start.xform_inv(global_transform.origin).project(translation_basis)[dof.primary_axis]
				var retracted_body_axial_displacement: float = body_axial_displacement
				
				match dof.retract_mode:
					dof.RetractMode.RETRACTS_OPEN:
						retracted_body_axial_displacement += (dof.retract_speed * delta)
					dof.RetractMode.RETRACTS_CLOSED:
						retracted_body_axial_displacement -= (dof.retract_speed * delta)
				
				retracted_body_axial_displacement = _latch_within_dist(body_axial_displacement, retracted_body_axial_displacement, dof.open_rom, dof.latch_dist, dof.open_latch_mode)
				retracted_body_axial_displacement = _latch_within_dist(body_axial_displacement, retracted_body_axial_displacement, dof.close_rom, dof.latch_dist, dof.close_latch_mode)
				retracted_body_axial_displacement = _limit_max_rom(body_axial_displacement, retracted_body_axial_displacement, dof.close_rom, dof.open_rom, i) # BUG: 'moving' signal emits constantly
				
				if dof.open_rom > 0:
					open_percentage[dof] = clamp_with_result(retracted_body_axial_displacement, -dof.close_rom, 0).overflow / dof.open_rom
				if dof.close_rom > 0:	
					close_percentage[dof] = clamp_with_result(retracted_body_axial_displacement, -dof.close_rom, 0).overflow / dof.open_rom
				_emit_ticks(body_axial_displacement, retracted_body_axial_displacement, dof.close_rom, dof.open_rom, dof.num_ticks, i)		# BUG: ticks emit constantly at max rom
				total_displacement[dof.primary_axis] += retracted_body_axial_displacement
		global_transform = _start.translated(total_displacement)
		
		for i in len(dofs):
			var dof: DoF = dofs[i] as DoF
			if dof.mode == DoF.DoFMode.ROTATION:
				var rotation_basis: Vector3 = global_transform.basis[dof.primary_axis]
				var retracted_axial_rotation: float = 0
				
				match dof.retract_mode:
					dof.RetractMode.RETRACTS_OPEN:
						retracted_axial_rotation = _prior_rotations[dof.primary_axis] + (dof.retract_speed * delta)
					dof.RetractMode.RETRACTS_CLOSED:
						retracted_axial_rotation = _prior_rotations[dof.primary_axis] - (dof.retract_speed * delta)
					dof.RetractMode.NO_RETRACT:
						retracted_axial_rotation = _prior_rotations[dof.primary_axis]
				
				retracted_axial_rotation = _latch_within_dist(_prior_rotations[dof.primary_axis], retracted_axial_rotation, dof.open_rom, dof.latch_dist, dof.open_latch_mode)
				retracted_axial_rotation = _latch_within_dist(_prior_rotations[dof.primary_axis], retracted_axial_rotation, dof.close_rom, dof.latch_dist, dof.close_latch_mode)
				retracted_axial_rotation = _limit_speed(_prior_rotations[dof.primary_axis], retracted_axial_rotation, dof.max_open_speed, dof.max_close_speed, delta, dof)
				retracted_axial_rotation = _limit_max_rom(_prior_rotations[dof.primary_axis], retracted_axial_rotation, dof.close_rom, dof.open_rom, i)
				
				if dof.open_rom > 0:
					open_percentage[dof] = clamp_with_result(retracted_axial_rotation, -dof.close_rom, 0).overflow / dof.open_rom
				if dof.close_rom > 0:
					close_percentage[dof] = clamp_with_result(retracted_axial_rotation, -dof.close_rom, 0).overflow / dof.open_rom
				_emit_ticks(_prior_rotations[dof.primary_axis], retracted_axial_rotation, dof.close_rom, dof.open_rom, dof.num_ticks, i)

				_prior_rotations[dof.primary_axis] = retracted_axial_rotation
				global_transform.basis = global_transform.basis.rotated(rotation_basis, retracted_axial_rotation)

func _latch_within_dist(current_axial_displacement, holder_axial_displacement, rom, latch_dist, latch_mode) -> float:
	var delta_axial_displacement: float = abs(current_axial_displacement) - abs(holder_axial_displacement)
	if is_equal_approx(abs(current_axial_displacement), abs(rom)) and latch_mode != DoF.LatchMode.NEVER_LATCH:
		var distance_limit: float = latch_dist if latch_mode == DoF.LatchMode.LATCH_WITHIN_DIST else -INF
		if delta_axial_displacement < distance_limit:
			holder_axial_displacement = current_axial_displacement
	return holder_axial_displacement

func _limit_speed(current_axial_displacement, holder_axial_displacement, max_open_speed, max_close_speed, delta, dof) -> float:
	if max_open_speed > 0:
		var clamp_result: ClampResult = clamp_with_result(holder_axial_displacement,
			-INF,
			current_axial_displacement+(max_open_speed * delta))
		holder_axial_displacement = clamp_result.result
		if clamp_result.bounds != ClampResult.Bounds.IN_RANGE:
			force_excesses[dof] = clamp_result.overflow
	if max_close_speed > 0:
		var clamp_result: ClampResult= clamp_with_result(holder_axial_displacement, 
			current_axial_displacement-(max_close_speed * delta),
			INF)
		holder_axial_displacement = clamp_result.result
		if clamp_result.bounds != ClampResult.Bounds.IN_RANGE:
			force_excesses[dof] = clamp_result.overflow
	return holder_axial_displacement

func _limit_max_rom(current_axial_displacement, holder_axial_displacement, close_rom, open_rom, dof_index) -> float:
	var clamp_result: ClampResult = clamp_with_result(holder_axial_displacement, -close_rom, open_rom)
	holder_axial_displacement = clamp_result.result
	# FIXME: Use DoFStatus and a dictionary to simplify this check
	match clamp_result.bounds:
		ClampResult.Bounds.LOWER_THAN_RANGE:
			if !is_equal_approx(current_axial_displacement, -close_rom):
				emit_signal("closed", dof_index)
		ClampResult.Bounds.IN_RANGE:
			if (is_equal_approx(current_axial_displacement, -close_rom)
				or is_equal_approx(current_axial_displacement, open_rom)):
				emit_signal("moving", dof_index)
		ClampResult.Bounds.GREATER_THAN_RANGE:
			if !is_equal_approx(current_axial_displacement, open_rom):
				emit_signal("opened", dof_index)
	return holder_axial_displacement

func _emit_ticks(current_axial_displacement, holder_axial_displacement, close_rom, open_rom, num_ticks, dof_index):
	if num_ticks > 0:
		var total_rom: float = open_rom + close_rom # FIXME: This should be calculated in the resource to optimise
		var tick_distance: float = total_rom / num_ticks
		if floor(holder_axial_displacement / tick_distance) != floor(current_axial_displacement / tick_distance):
			emit_signal("tick", dof_index)

func _grabbed(holder: Spatial):
	_holder = holder;
#	_holder_transform_at_grab = _holder.global_transform

func _released():
	_holder = null;

func clamp_with_result(value: float, mini: float, maxi: float) -> ClampResult:
	var clamped_val: float = clamp(value, mini, maxi)
	var bounds: int
	var overflow: float
	if value <= mini:
		bounds = ClampResult.Bounds.LOWER_THAN_RANGE
		overflow = abs(mini - value)
	elif value >= maxi:
		bounds = ClampResult.Bounds.GREATER_THAN_RANGE
		overflow = abs(value - maxi)
	else:
		bounds = ClampResult.Bounds.IN_RANGE
		overflow = 0
	return ClampResult.new(clamped_val, bounds, overflow)

class ClampResult:
	extends Reference
	enum Bounds {
		GREATER_THAN_RANGE,
		LOWER_THAN_RANGE,
		IN_RANGE
	}
	var result: float
	var bounds: int
	var overflow: float
	
	func _init(r, b, o):
		result = r
		bounds = b
		overflow = o
	
