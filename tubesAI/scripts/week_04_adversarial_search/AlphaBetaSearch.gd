class_name AlphaBetaSearch
extends RefCounted

static var node_count: int = 0

static func search(state, depth: int, alpha: float, beta: float, maximizing: bool, profile: String, move_order: Array[String], use_pruning: bool, node_limit: int, actions_fn: Callable, transition_fn: Callable, evaluate_fn: Callable) -> Dictionary:
	node_count = 0
	return _search(state, depth, alpha, beta, maximizing, profile, move_order, use_pruning, node_limit, actions_fn, transition_fn, evaluate_fn)

static func _search(state, depth: int, alpha: float, beta: float, maximizing: bool, profile: String, move_order: Array[String], use_pruning: bool, node_limit: int, actions_fn: Callable, transition_fn: Callable, evaluate_fn: Callable) -> Dictionary:
	if node_limit > 0 and node_count >= node_limit:
		return {"score": evaluate_fn.call(state, profile), "action": "", "evals": {}}
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
			var score: float = _search(child, depth - 1, alpha, beta, false, profile, move_order, use_pruning, node_limit, actions_fn, transition_fn, evaluate_fn)["score"]
			action_scores[action] = score
			if score > best_score:
				best_score = score
				best_action = action
			alpha = maxf(alpha, best_score)
			if use_pruning and alpha >= beta:
				break
		return {"score": best_score, "action": best_action, "evals": action_scores}

	var best_score := INF
	for action in actions:
		var child = transition_fn.call(state, action, false)
		var score: float = _search(child, depth - 1, alpha, beta, true, profile, move_order, use_pruning, node_limit, actions_fn, transition_fn, evaluate_fn)["score"]
		action_scores[action] = score
		if score < best_score:
			best_score = score
			best_action = action
		beta = minf(beta, best_score)
		if use_pruning and alpha >= beta:
			break
	return {"score": best_score, "action": best_action, "evals": action_scores}
