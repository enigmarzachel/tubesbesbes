class_name MinimaxSearch
extends RefCounted

static var node_count: int = 0

static func search(state, depth: int, maximizing: bool, profile: String, move_order: Array[String], actions_fn: Callable, transition_fn: Callable, evaluate_fn: Callable) -> Dictionary:
	node_count = 0
	return _search(state, depth, maximizing, profile, move_order, actions_fn, transition_fn, evaluate_fn)

static func _search(state, depth: int, maximizing: bool, profile: String, move_order: Array[String], actions_fn: Callable, transition_fn: Callable, evaluate_fn: Callable) -> Dictionary:
	node_count += 1
	if state.hp_player <= 0:
		return {"score": 10000.0 + depth, "action": "", "evals": {}}
	if state.hp_npc <= 0:
		return {"score": -10000.0 - depth, "action": "", "evals": {}}
	if depth <= 0:
		return {"score": evaluate_fn.call(state, profile), "action": "", "evals": {}}

	var actions: Array[String] = actions_fn.call(state, maximizing, move_order)
	var best_action: String = actions[0]
	var action_scores: Dictionary = {}
	if maximizing:
		var best_score := -INF
		for action in actions:
			var child = transition_fn.call(state, action, true)
			var score: float = _search(child, depth - 1, false, profile, move_order, actions_fn, transition_fn, evaluate_fn)["score"]
			action_scores[action] = score
			if score > best_score:
				best_score = score
				best_action = action
		return {"score": best_score, "action": best_action, "evals": action_scores}

	var best_score := INF
	for action in actions:
		var child = transition_fn.call(state, action, false)
		var score: float = _search(child, depth - 1, true, profile, move_order, actions_fn, transition_fn, evaluate_fn)["score"]
		action_scores[action] = score
		if score < best_score:
			best_score = score
			best_action = action
	return {"score": best_score, "action": best_action, "evals": action_scores}
