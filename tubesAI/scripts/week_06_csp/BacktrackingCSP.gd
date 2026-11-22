class_name BacktrackingCSP
extends RefCounted

## Backtracking CSP with MRV, degree tie-break, LCV, forward checking and MAC.
static func solve(
	solver: CSPSolver,
	variables: Array[Vector2i],
	domains: Dictionary,
	constraints: Dictionary,
	use_ac3: bool = true,
	use_forward_checking: bool = true
) -> Dictionary:
	var started := Time.get_ticks_msec()
	solver.backtrack_steps = 0
	solver.pruned_values_count = 0
	solver.ac3_revisions_count = 0
	var working_domains := _copy_domains(variables, domains, solver, constraints)
	if variables.is_empty():
		return _result(solver, true, {}, started, "", use_ac3)
	for variable in variables:
		if working_domains[variable].is_empty():
			return _result(solver, false, {}, started, "Domain kosong untuk %s." % variable, use_ac3)
	if use_ac3 and not solver.run_ac3(variables, working_domains, constraints):
		return _result(solver, false, {}, started, "AC-3 mendeteksi domain kosong.", use_ac3)
	var unassigned: Array[Vector2i] = []
	unassigned.append_array(variables)
	var assignment: Dictionary = {}
	var success := _search(solver, assignment, unassigned, working_domains, variables, constraints, use_ac3, use_forward_checking)
	return _result(solver, success, assignment if success else {}, started, "", use_ac3)

static func _copy_domains(variables: Array[Vector2i], domains: Dictionary, solver: CSPSolver, constraints: Dictionary) -> Dictionary:
	var copied := {}
	for variable in variables:
		var values: Array = []
		for value in domains.get(variable, []):
			if solver.is_unary_consistent(variable, value, constraints):
				values.append(value)
		copied[variable] = values
	return copied

static func _copy_all_domains(variables: Array[Vector2i], domains: Dictionary) -> Dictionary:
	var copied := {}
	for variable in variables:
		copied[variable] = domains.get(variable, []).duplicate(true)
	return copied

static func _search(solver: CSPSolver, assignment: Dictionary, unassigned: Array[Vector2i], domains: Dictionary,
	all_vars: Array[Vector2i], constraints: Dictionary, use_ac3: bool, use_fc: bool) -> bool:
	solver.backtrack_steps += 1
	if unassigned.is_empty():
		return solver.is_global_consistent(assignment, constraints, false)
	var variable := solver.select_unassigned_variable_mrv(unassigned, domains, all_vars, constraints)
	var ordered_values := solver.order_domain_values_lcv(variable, domains.get(variable, []), unassigned, domains, constraints)
	var remaining: Array[Vector2i] = []
	remaining.append_array(unassigned)
	remaining.erase(variable)
	for value in ordered_values:
		var consistent := true
		for assigned_var in assignment:
			if not solver.is_binary_consistent(variable, value, assigned_var, assignment[assigned_var], constraints):
				consistent = false
				break
		if not consistent:
			continue
		assignment[variable] = value
		if not solver.is_global_consistent(assignment, constraints, true):
			assignment.erase(variable)
			continue
		var branch_domains := _copy_all_domains(all_vars, domains)
		branch_domains[variable] = [value]
		var inference_ok := true
		if use_ac3:
			inference_ok = solver.run_ac3(all_vars, branch_domains, constraints)
		elif use_fc:
			var fc := solver.forward_check(variable, value, remaining, branch_domains, constraints, assignment)
			inference_ok = fc.success
		if inference_ok and _search(solver, assignment, remaining, branch_domains, all_vars, constraints, use_ac3, use_fc):
			return true
		assignment.erase(variable)
	return false

static func _result(solver: CSPSolver, success: bool, assignment: Dictionary, started: int, error: String = "", use_ac3: bool = true) -> Dictionary:
	solver.execution_time_ms = Time.get_ticks_msec() - started
	var result := {
		"success": success,
		"method": "BACKTRACKING_MRV_DEGREE_LCV_MAC" if use_ac3 else "BACKTRACKING_MRV_DEGREE_LCV_FC",
		"assignment": assignment,
		"steps": solver.backtrack_steps,
		"pruned_values": solver.pruned_values_count,
		"ac3_revisions": solver.ac3_revisions_count,
		"time_ms": solver.execution_time_ms
	}
	if not error.is_empty():
		result.error = error
	return result
