class_name ExpectimaxSearch
extends RefCounted

static var node_count: int = 0
const HEAVY_ATTACK_HIT_PROBABILITY: float = 0.8

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
	var best_score := -INF if maximizing else INF
	for action in actions:
		var score: float
		if action == "HEAVY_ATTACK":
			var hit_state = transition_fn.call(state, action, maximizing)
			var miss_state = state.duplicate_state()
			if maximizing:
				miss_state.def_npc = false
			else:
				miss_state.def_player = false
			var hit_score: float = _search(hit_state, depth - 1, not maximizing, profile, move_order, actions_fn, transition_fn, evaluate_fn)["score"]
			var miss_score: float = _search(miss_state, depth - 1, not maximizing, profile, move_order, actions_fn, transition_fn, evaluate_fn)["score"]
			score = HEAVY_ATTACK_HIT_PROBABILITY * hit_score + (1.0 - HEAVY_ATTACK_HIT_PROBABILITY) * miss_score
		else:
			var child = transition_fn.call(state, action, maximizing)
			score = _search(child, depth - 1, not maximizing, profile, move_order, actions_fn, transition_fn, evaluate_fn)["score"]
		action_scores[action] = score
		if (maximizing and score > best_score) or (not maximizing and score < best_score):
			best_score = score
			best_action = action
	return {"score": best_score, "action": best_action, "evals": action_scores}
