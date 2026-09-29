class_name MinimaxAI
extends RefCounted

static var node_count: int = 0

class BattleState:
	var hp_player: int = 100
	var hp_npc: int = 100
	var potion_player: int = 2
	var potion_npc: int = 2
	var def_player: bool = false
	var def_npc: bool = false
	
	func duplicate_state() -> BattleState:
		var s = BattleState.new()
		s.hp_player = hp_player
		s.hp_npc = hp_npc
		s.potion_player = potion_player
		s.potion_npc = potion_npc
		s.def_player = def_player
		s.def_npc = def_npc
		return s

static func get_valid_actions(state: BattleState, is_npc: bool, custom_order: Array[String] = []) -> Array[String]:
	var available: Array[String] = ["ATTACK", "DEFEND"]
	var potions = state.potion_npc if is_npc else state.potion_player
	if potions > 0:
		available.append("POTION")
	available.append("HEAVY_ATTACK")
	
	if custom_order.is_empty():
		return available
		
	var ordered: Array[String] = []
	for act in custom_order:
		if act in available:
			ordered.append(act)
	for act in available:
		if not (act in ordered):
			ordered.append(act)
	return ordered

static func apply_action(state: BattleState, action: String, is_npc: bool) -> BattleState:
	var next_s = state.duplicate_state()
	if is_npc:
		next_s.def_npc = false
		match action:
			"ATTACK":
				var dmg = 10 if next_s.def_player else 20
				next_s.hp_player = max(0, next_s.hp_player - dmg)
			"DEFEND":
				next_s.def_npc = true
			"POTION":
				next_s.hp_npc = min(100, next_s.hp_npc + 25)
				next_s.potion_npc = max(0, next_s.potion_npc - 1)
			"HEAVY_ATTACK":
				var dmg = 15 if next_s.def_player else 30
				next_s.hp_player = max(0, next_s.hp_player - dmg)
	else:
		next_s.def_player = false
		match action:
			"ATTACK":
				var dmg = 10 if next_s.def_npc else 20
				next_s.hp_npc = max(0, next_s.hp_npc - dmg)
			"DEFEND":
				next_s.def_player = true
			"POTION":
				next_s.hp_player = min(100, next_s.hp_player + 25)
				next_s.potion_player = max(0, next_s.potion_player - 1)
			"HEAVY_ATTACK":
				var dmg = 15 if next_s.def_npc else 30
				next_s.hp_npc = max(0, next_s.hp_npc - dmg)
	return next_s

static func evaluate(state: BattleState, profile: String) -> float:
	var w_hp: float = 1.2
	var w_pot: float = 5.0
	var w_def: float = 2.0
	
	match profile:
		"AGGRESSIVE":
			w_hp = 3.0
			w_pot = 2.0
			w_def = 0.5
		"DEFENSIVE":
			w_hp = 0.8
			w_pot = 10.0
			w_def = 6.0
		"BALANCED":
			w_hp = 1.2
			w_pot = 5.0
			w_def = 2.0
			
	var hp_diff = float(state.hp_npc - state.hp_player)
	var pot_diff = float(state.potion_npc - state.potion_player)
	var def_bonus = (1.0 if state.def_npc else 0.0) - (1.0 if state.def_player else 0.0)
	
	return (w_hp * hp_diff) + (w_pot * pot_diff) + (w_def * def_bonus)

# Alpha-Beta / Minimax Search
static func alphabeta(
	state: BattleState, 
	depth: int, 
	alpha: float, 
	beta: float, 
	maximizing: bool, 
	profile: String, 
	use_pruning: bool = true,
	move_order: Array[String] = []
) -> Dictionary:
	node_count += 1
	
	if state.hp_player <= 0:
		return {"score": 10000.0 + depth, "action": "", "evals": {}}
	if state.hp_npc <= 0:
		return {"score": -10000.0 - depth, "action": "", "evals": {}}
		
	if depth == 0:
		return {"score": evaluate(state, profile), "action": "", "evals": {}}
		
	var actions = get_valid_actions(state, maximizing, move_order)
	var best_action = actions[0]
	var action_scores = {}
	
	if maximizing:
		var max_eval = -INF
		for act in actions:
			var next_state = apply_action(state, act, true)
			var res = alphabeta(next_state, depth - 1, alpha, beta, false, profile, use_pruning, move_order)
			var current_score = res["score"]
			action_scores[act] = current_score
			
			if current_score > max_eval:
				max_eval = current_score
				best_action = act
				
			alpha = max(alpha, max_eval)
			if use_pruning and alpha >= beta:
				break
		return {"score": max_eval, "action": best_action, "evals": action_scores}
		
	else:
		var min_eval = INF
		for act in actions:
			var next_state = apply_action(state, act, false)
			var res = alphabeta(next_state, depth - 1, alpha, beta, true, profile, use_pruning, move_order)
			var current_score = res["score"]
			action_scores[act] = current_score
			
			if current_score < min_eval:
				min_eval = current_score
				best_action = act
				
			beta = min(beta, min_eval)
			if use_pruning and alpha >= beta:
				break
		return {"score": min_eval, "action": best_action, "evals": action_scores}

# Expectimax Search (Peluang 80% Heavy Attack Hit, 20% Miss)
static func expectimax(
	state: BattleState, 
	depth: int, 
	maximizing: bool, 
	profile: String,
	move_order: Array[String] = []
) -> Dictionary:
	node_count += 1
	
	if state.hp_player <= 0: return {"score": 10000.0 + depth, "action": "", "evals": {}}
	if state.hp_npc <= 0: return {"score": -10000.0 - depth, "action": "", "evals": {}}
	if depth == 0: return {"score": evaluate(state, profile), "action": "", "evals": {}}
	
	var actions = get_valid_actions(state, maximizing, move_order)
	var best_action = actions[0]
	var action_scores = {}
	
	if maximizing:
		var max_eval = -INF
		for act in actions:
			var eval_val = 0.0
			if act == "HEAVY_ATTACK":
				var hit_state = apply_action(state, "HEAVY_ATTACK", true)
				var miss_state = state.duplicate_state()
				miss_state.def_npc = false
				var res_hit = expectimax(hit_state, depth - 1, false, profile, move_order)
				var res_miss = expectimax(miss_state, depth - 1, false, profile, move_order)
				eval_val = (0.8 * res_hit["score"]) + (0.2 * res_miss["score"])
			else:
				var next_state = apply_action(state, act, true)
				var res = expectimax(next_state, depth - 1, false, profile, move_order)
				eval_val = res["score"]
				
			action_scores[act] = eval_val
			if eval_val > max_eval:
				max_eval = eval_val
				best_action = act
		return {"score": max_eval, "action": best_action, "evals": action_scores}
	else:
		var min_eval = INF
		for act in actions:
			var next_state = apply_action(state, act, false)
			var res = expectimax(next_state, depth - 1, true, profile, move_order)
			var eval_val = res["score"]
			action_scores[act] = eval_val
			if eval_val < min_eval:
				min_eval = eval_val
				best_action = act
		return {"score": min_eval, "action": best_action, "evals": action_scores}
