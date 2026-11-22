class_name MinimaxAI
extends RefCounted

static var node_count: int = 0

class BattleState:
	var hp_player: int = 100
	var hp_npc: int = 100
	var max_hp_player: int = 100
	var max_hp_npc: int = 100
	var attack_player: int = 20
	var attack_npc: int = 20
	var defense_player: int = 5
	var defense_npc: int = 5
	var potion_player: int = 2
	var potion_npc: int = 2
	var def_player: bool = false
	var def_npc: bool = false

	func duplicate_state() -> BattleState:
		var s = BattleState.new()
		s.hp_player = hp_player; s.hp_npc = hp_npc
		s.max_hp_player = max_hp_player; s.max_hp_npc = max_hp_npc
		s.attack_player = attack_player; s.attack_npc = attack_npc
		s.defense_player = defense_player; s.defense_npc = defense_npc
		s.potion_player = potion_player; s.potion_npc = potion_npc
		s.def_player = def_player; s.def_npc = def_npc
		return s

static func get_valid_actions(state: BattleState, is_npc: bool, custom_order: Array[String] = []) -> Array[String]:
	var available: Array[String] = ["ATTACK", "DEFEND"]
	if (state.potion_npc if is_npc else state.potion_player) > 0:
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
	var s = state.duplicate_state()
	if is_npc:
		s.def_npc = false
		match action:
			"ATTACK":
				s.hp_player = maxi(0, s.hp_player - _get_damage(s.attack_npc, s.defense_player, s.def_player))
			"DEFEND":
				s.def_npc = true
			"POTION":
				s.hp_npc = mini(s.max_hp_npc, s.hp_npc + 25)
				s.potion_npc = max(0, s.potion_npc - 1)
			"HEAVY_ATTACK":
				s.hp_player = maxi(0, s.hp_player - _get_damage(roundi(s.attack_npc * 1.5), s.defense_player, s.def_player))
	else:
		s.def_player = false
		match action:
			"ATTACK":
				s.hp_npc = maxi(0, s.hp_npc - _get_damage(s.attack_player, s.defense_npc, s.def_npc))
			"DEFEND":
				s.def_player = true
			"POTION":
				s.hp_player = mini(s.max_hp_player, s.hp_player + 25)
				s.potion_player = max(0, s.potion_player - 1)
			"HEAVY_ATTACK":
				s.hp_npc = maxi(0, s.hp_npc - _get_damage(roundi(s.attack_player * 1.5), s.defense_npc, s.def_npc))
	return s

static func _get_damage(raw_damage: int, target_defense: int, is_defending: bool) -> int:
	var damage = maxi(1, raw_damage - maxi(0, target_defense))
	if is_defending:
		damage = maxi(1, ceili(float(damage) * 0.5))
	return damage

## Resolve an action in Expectimax mode: heavy attacks hit with 80% probability.
static func apply_expectimax_action(state: BattleState, action: String, is_npc: bool) -> Dictionary:
	if action != "HEAVY_ATTACK" or randf() < 0.8:
		return {"state": apply_action(state, action, is_npc), "hit": true}
	var missed = state.duplicate_state()
	if is_npc:
		missed.def_npc = false
	else:
		missed.def_player = false
	return {"state": missed, "hit": false}

static func evaluate(state: BattleState, profile: String) -> float:
	var w_hp: float; var w_pot: float; var w_def: float
	match profile:
		"AGGRESSIVE":
			w_hp = 3.0; w_pot = 2.0; w_def = 0.5
		"DEFENSIVE":
			w_hp = 0.8; w_pot = 10.0; w_def = 6.0
		_: # BALANCED
			w_hp = 1.2; w_pot = 5.0; w_def = 2.0

	return (w_hp * float(state.hp_npc - state.hp_player)
		+ w_pot * float(state.potion_npc - state.potion_player)
		+ w_def * ((1.0 if state.def_npc else 0.0) - (1.0 if state.def_player else 0.0)))

# Minimax and Alpha-Beta use separate search modules; this class keeps the shared game model/API.
static func alphabeta(
	state: BattleState, depth: int, alpha: float, beta: float,
	maximizing: bool, profile: String, use_pruning: bool = true,
	move_order: Array[String] = [], node_limit: int = -1
) -> Dictionary:
	var result: Dictionary
	if not use_pruning and node_limit <= 0:
		result = MinimaxSearch.search(state, depth, maximizing, profile, move_order,
			Callable(MinimaxAI, "get_valid_actions"), Callable(MinimaxAI, "apply_action"), Callable(MinimaxAI, "evaluate"))
		node_count = MinimaxSearch.node_count
	else:
		result = AlphaBetaSearch.search(state, depth, alpha, beta, maximizing, profile, move_order, use_pruning, node_limit,
			Callable(MinimaxAI, "get_valid_actions"), Callable(MinimaxAI, "apply_action"), Callable(MinimaxAI, "evaluate"))
		node_count = AlphaBetaSearch.node_count
	return result

# Expectimax is kept in a dedicated file; the shared transition/evaluation model stays here.
static func expectimax(
	state: BattleState, depth: int, maximizing: bool, profile: String,
	move_order: Array[String] = []
) -> Dictionary:
	var result = ExpectimaxSearch.search(state, depth, maximizing, profile, move_order,
		Callable(MinimaxAI, "get_valid_actions"), Callable(MinimaxAI, "apply_action"), Callable(MinimaxAI, "evaluate"))
	node_count = ExpectimaxSearch.node_count
	return result
