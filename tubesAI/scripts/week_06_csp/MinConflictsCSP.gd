class_name MinConflictsCSP
extends RefCounted

## Local-search CSP solver. It keeps the best assignment seen when the step cap is reached.
static func solve(solver: CSPSolver, variables: Array[Vector2i], domains: Dictionary,
	constraints: Dictionary, max_steps: int = 500, initial_assignment: Dictionary = {}) -> Dictionary:
	var started := Time.get_ticks_msec()
	solver.execution_time_ms = 0
	if variables.is_empty():
		return _result(solver, true, {}, 0, started, constraints, 0)
	for variable in variables:
		if domains.get(variable, []).is_empty():
			return _result(solver, false, {}, 0, started, constraints, 0, "Domain kosong untuk %s." % variable)
	var current: Dictionary = {}
	for variable in variables:
		if initial_assignment.has(variable) and domains[variable].has(initial_assignment[variable]):
			current[variable] = initial_assignment[variable]
		else:
			var values: Array = domains[variable]
			var best_value = values[0]
			var fewest := 2147483647
			for value in values:
				var trial := current.duplicate(true)
				trial[variable] = value
				var conflicts := _variable_conflicts(solver, variable, value, trial, constraints)
				if conflicts < fewest:
					fewest = conflicts
					best_value = value
			current[variable] = best_value
	var best_assignment := current.duplicate(true)
	var best_conflicts := _total_conflicts(solver, current, constraints)
	var steps_taken := 0
	for step in range(maxi(0, max_steps)):
		steps_taken = step + 1
		if best_conflicts == 0:
			return _result(solver, true, best_assignment, steps_taken, started, constraints, 0)
		var conflicted: Array[Vector2i] = []
		for variable in variables:
			if _variable_conflicts(solver, variable, current[variable], current, constraints) > 0:
				conflicted.append(variable)
		if conflicted.is_empty():
			break
		var chosen: Vector2i = conflicted[randi() % conflicted.size()]
		var candidates: Array = []
		var lowest := 2147483647
		for value in domains[chosen]:
			var trial := current.duplicate(true)
			trial[chosen] = value
			var score := _total_conflicts(solver, trial, constraints)
			if score < lowest:
				lowest = score
				candidates.clear()
				candidates.append(value)
			elif score == lowest:
				candidates.append(value)
		if not candidates.is_empty():
			current[chosen] = candidates[randi() % candidates.size()]
		var score := _total_conflicts(solver, current, constraints)
		if score < best_conflicts:
			best_conflicts = score
			best_assignment = current.duplicate(true)
	return _result(solver, best_conflicts == 0, best_assignment, steps_taken, started, constraints, best_conflicts,
		"Batas langkah tercapai; dikembalikan assignment terbaik." if best_conflicts > 0 else "")

static func _variable_conflicts(solver: CSPSolver, variable: Vector2i, value: Dictionary, assignment: Dictionary, constraints: Dictionary) -> int:
	var conflicts := 0 if solver.is_unary_consistent(variable, value, constraints) else 10
	for other in assignment:
		if other != variable and not solver.is_binary_consistent(variable, value, other, assignment[other], constraints):
			conflicts += 1
	var trial := assignment.duplicate(true)
	trial[variable] = value
	if not solver.is_global_consistent(trial, constraints, false):
		conflicts += 3
	return conflicts

static func _total_conflicts(solver: CSPSolver, assignment: Dictionary, constraints: Dictionary) -> int:
	var total := 0
	for variable in assignment:
		if not solver.is_unary_consistent(variable, assignment[variable], constraints):
			total += 5
	for index in range(assignment.size()):
		var vars := assignment.keys()
		for other_index in range(index + 1, vars.size()):
			if not solver.is_binary_consistent(vars[index], assignment[vars[index]], vars[other_index], assignment[vars[other_index]], constraints):
				total += 1
	if not solver.is_global_consistent(assignment, constraints, false):
		total += 3
	return total

static func _result(solver: CSPSolver, success: bool, assignment: Dictionary, steps: int, started: int,
	constraints: Dictionary, conflicts: int, error: String = "") -> Dictionary:
	solver.execution_time_ms = Time.get_ticks_msec() - started
	var result := {"success": success, "method": "MIN_CONFLICTS", "assignment": assignment,
		"steps": steps, "conflicts": conflicts, "time_ms": solver.execution_time_ms}
	if not error.is_empty():
		result.error = error
	return result
