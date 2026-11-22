class_name AutomatedPlanner
extends RefCounted

## STRIPS planner over grounded propositional facts (closed-world semantics).
## Action dictionaries: {name, preconditions:Array[String], add:Array[String], delete:Array[String]}.
static func plan_forward(initial: Array[String], static_facts: Array[String], goal: Array[String], actions: Array[Dictionary], max_states: int = 20000) -> Dictionary:
	var start := _set_from(initial + static_facts)
	if _contains_all(start, goal):
		return _result(true, [], start, 0, "forward")
	var queue: Array[Dictionary] = [{"facts": start, "plan": []}]
	var seen: Dictionary = {_state_key(start): true}
	var expanded := 0
	while not queue.is_empty() and expanded < max_states:
		var current: Dictionary = queue.pop_front()
		expanded += 1
		for action in actions:
			if not _contains_all(current.facts, action.get("preconditions", [])):
				continue
			var next_facts := _apply(current.facts, action)
			var key := _state_key(next_facts)
			if seen.has(key):
				continue
			var next_plan: Array = current.plan.duplicate()
			next_plan.append(String(action.get("name", "action")))
			if _contains_all(next_facts, goal):
				return _result(true, next_plan, next_facts, expanded, "forward")
			seen[key] = true
			queue.append({"facts": next_facts, "plan": next_plan})
	return _result(false, [], start, expanded, "forward", "Goal tidak tercapai atau batas state habis.")

static func plan_backward(initial: Array[String], static_facts: Array[String], goal: Array[String], actions: Array[Dictionary], max_states: int = 20000) -> Dictionary:
	var start_facts := _set_from(initial + static_facts)
	if _contains_all(start_facts, goal):
		return _result(true, [], start_facts, 0, "backward")
	var queue: Array[Dictionary] = [{"goal": _set_from(goal), "plan": []}]
	var seen: Dictionary = {_state_key(_set_from(goal)): true}
	var expanded := 0
	while not queue.is_empty() and expanded < max_states:
		var current: Dictionary = queue.pop_front()
		expanded += 1
		for index in range(actions.size()):
			var action: Dictionary = actions[index]
			var adds: Array = action.get("add", [])
			var deletes: Array = action.get("delete", [])
			if not _intersects(current.goal, adds) or _intersects(current.goal, deletes):
				continue
			var regressed: Dictionary = current.goal.duplicate()
			for fact in adds:
				regressed.erase(String(fact))
			for fact in action.get("preconditions", []):
				regressed[String(fact)] = true
			var regressed_array := _array_from_set(regressed)
			var plan: Array = current.plan.duplicate()
			plan.push_front(String(action.get("name", "action")))
			if _contains_all(start_facts, regressed_array):
				return _result(true, plan, start_facts, expanded, "backward")
			var key := _state_key(regressed)
			if not seen.has(key):
				seen[key] = true
				queue.append({"goal": regressed, "plan": plan})
	return _result(false, [], start_facts, expanded, "backward", "Tidak ditemukan regresi hingga initial state.")

## Ignore-delete-lists heuristic: relaxed reachability levels to satisfy all goals.
static func ignore_delete_heuristic(facts: Array[String], goal: Array[String], actions: Array[Dictionary], max_levels: int = 128) -> Dictionary:
	var relaxed := _set_from(facts)
	if _contains_all(relaxed, goal):
		return {"value": 0, "reached": true, "levels": 0}
	for level in range(1, max_levels + 1):
		var additions: Dictionary = {}
		for action in actions:
			if _contains_all(relaxed, action.get("preconditions", [])):
				for fact in action.get("add", []):
					additions[String(fact)] = true
		for fact in additions:
			relaxed[fact] = true
		if _contains_all(relaxed, goal):
			return {"value": level, "reached": true, "levels": level}
	return {"value": max_levels, "reached": false, "levels": max_levels}

## One planning-graph level with noop actions and mutex annotations.
static func planning_graph_level(facts: Array[String], static_facts: Array[String], actions: Array[Dictionary], prior_fact_mutex: Dictionary = {}) -> Dictionary:
	var source := _set_from(facts + static_facts)
	var applicable: Array[Dictionary] = []
	for fact in source:
		applicable.append({"name": "noop:%s" % fact, "preconditions": [fact], "add": [fact], "delete": []})
	for action in actions:
		if _contains_all(source, action.get("preconditions", [])):
			applicable.append(action)
	var action_mutex: Dictionary = {}
	for i in range(applicable.size()):
		for j in range(i + 1, applicable.size()):
			if _actions_mutex(applicable[i], applicable[j], prior_fact_mutex):
				action_mutex[_pair_key(String(applicable[i].name), String(applicable[j].name))] = true
	var next_facts := source.duplicate()
	for action in applicable:
		for fact in action.get("add", []):
			next_facts[String(fact)] = true
	var producers: Dictionary = {}
	for fact in next_facts:
		producers[fact] = []
		for action in applicable:
			if fact in action.get("add", []):
				producers[fact].append(String(action.name))
	var fact_mutex: Dictionary = {}
	var next_array := _array_from_set(next_facts)
	for i in range(next_array.size()):
		for j in range(i + 1, next_array.size()):
			var all_mutex := true
			for producer_a in producers[next_array[i]]:
				for producer_b in producers[next_array[j]]:
					if producer_a == producer_b or not action_mutex.has(_pair_key(producer_a, producer_b)):
						all_mutex = false
				if not all_mutex:
					break
			if all_mutex:
				fact_mutex[_pair_key(next_array[i], next_array[j])] = true
	return {"facts": next_array, "actions": applicable, "action_mutex": action_mutex, "fact_mutex": fact_mutex}

static func _actions_mutex(a: Dictionary, b: Dictionary, prior_fact_mutex: Dictionary) -> bool:
	var a_pre: Array = a.get("preconditions", []); var b_pre: Array = b.get("preconditions", [])
	var a_add: Array = a.get("add", []); var b_add: Array = b.get("add", [])
	var a_del: Array = a.get("delete", []); var b_del: Array = b.get("delete", [])
	if _intersects(_set_from(a_del), b_pre) or _intersects(_set_from(a_del), b_add) or _intersects(_set_from(b_del), a_pre) or _intersects(_set_from(b_del), a_add):
		return true
	for pre_a in a_pre:
		for pre_b in b_pre:
			if prior_fact_mutex.has(_pair_key(String(pre_a), String(pre_b))):
				return true
	return false

static func _apply(state: Dictionary, action: Dictionary) -> Dictionary:
	var result: Dictionary = state.duplicate()
	for fact in action.get("delete", []): result.erase(String(fact))
	for fact in action.get("add", []): result[String(fact)] = true
	return result

static func _contains_all(state: Dictionary, facts: Array) -> bool:
	for fact in facts:
		if not state.has(String(fact)): return false
	return true

static func _intersects(state: Dictionary, facts: Array) -> bool:
	for fact in facts:
		if state.has(String(fact)): return true
	return false

static func _set_from(facts: Array) -> Dictionary:
	var result := {}
	for fact in facts: result[String(fact)] = true
	return result

static func _array_from_set(facts: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for fact in facts: result.append(String(fact))
	result.sort()
	return result

static func _state_key(state: Dictionary) -> String:
	return "|".join(PackedStringArray(_array_from_set(state)))

static func _pair_key(a: String, b: String) -> String:
	return "%s::%s" % [a, b] if a < b else "%s::%s" % [b, a]

static func _result(success: bool, plan: Array, state: Dictionary, expanded: int, method: String, error: String = "") -> Dictionary:
	var result := {"success": success, "plan": plan, "state": _array_from_set(state), "expanded": expanded, "method": method}
	if not error.is_empty(): result.error = error
	return result
