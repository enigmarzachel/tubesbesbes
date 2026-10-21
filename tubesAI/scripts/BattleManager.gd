class_name BattleManager
extends Node

signal battle_ended(winner_name: String)
signal stage_cleared()

@export var battle_ui_path: NodePath
@export var ai_depth: int = 4
@export_enum("BALANCED", "AGGRESSIVE", "DEFENSIVE") var ai_profile: String = "BALANCED"
@export var use_alpha_beta_pruning: bool = true
@export var use_expectimax: bool = false
@export var custom_move_order: Array[String] = ["ATTACK", "DEFEND", "POTION", "HEAVY_ATTACK"]

var current_state: MinimaxAI.BattleState
var battle_ui: CanvasLayer
var is_player_turn: bool = true
var current_enemy_node: Node2D = null
var current_player_node: Node2D = null

func _ready():
	add_to_group("battle_manager")
	if battle_ui_path:
		battle_ui = get_node_or_null(battle_ui_path)

func set_ai_profile(profile_name: String) -> void:
	ai_profile = profile_name

func set_ai_method(method_name: String) -> void:
	match method_name:
		"ALPHA_BETA":
			use_alpha_beta_pruning = true
			use_expectimax = false
		"MINIMAX":
			use_alpha_beta_pruning = false
			use_expectimax = false
		"EXPECTIMAX":
			use_expectimax = true
			use_alpha_beta_pruning = false

func set_ai_depth(depth: int) -> void:
	ai_depth = depth

func start_battle(enemy_node: Node2D, player_node: Node2D):
	current_enemy_node = enemy_node
	current_player_node = player_node

	if current_player_node:
		if current_player_node.has_method("face_enemy") and current_enemy_node:
			current_player_node.face_enemy(current_enemy_node)
		if current_player_node.has_method("set_battle_mode"):
			current_player_node.set_battle_mode(true)
		else:
			current_player_node.set_physics_process(false)
			current_player_node.set_process_unhandled_input(false)

	current_state = MinimaxAI.BattleState.new()
	current_state.hp_player = current_player_node.hp if (current_player_node and "hp" in current_player_node) else 100
	current_state.hp_npc = 100
	current_state.potion_player = 2
	current_state.potion_npc = 2

	if battle_ui and battle_ui.has_method("setup_ui"):
		battle_ui.setup_ui(self)
		battle_ui.show_battle_screen(true)
		battle_ui.update_display(current_state)

	is_player_turn = true
	if battle_ui and battle_ui.has_method("set_player_buttons_enabled"):
		battle_ui.set_player_buttons_enabled(true)

func execute_player_action(action_name: String):
	if not is_player_turn: return

	is_player_turn = false
	if battle_ui and battle_ui.has_method("set_player_buttons_enabled"):
		battle_ui.set_player_buttons_enabled(false)

	var npc_hp_before = current_state.hp_npc
	current_state = MinimaxAI.apply_action(current_state, action_name, false)

	await _play_attack_anim(current_player_node, action_name)

	if battle_ui and battle_ui.has_method("update_display"):
		battle_ui.update_display(current_state)
		battle_ui.append_log("Player menggunakan " + action_name)

	await _play_reaction_anim(current_enemy_node, npc_hp_before, current_state.hp_npc, false)

	if await check_battle_over(): return
	await get_tree().create_timer(0.6).timeout
	execute_npc_turn()

func execute_npc_turn():
	# Hitung node untuk perbandingan algoritma
	MinimaxAI.node_count = 0
	MinimaxAI.alphabeta(current_state, ai_depth, -INF, INF, true, ai_profile, false)
	var nodes_minimax = MinimaxAI.node_count

	MinimaxAI.node_count = 0
	MinimaxAI.alphabeta(current_state, ai_depth, -INF, INF, true, ai_profile, true)
	var nodes_ab = MinimaxAI.node_count

	MinimaxAI.node_count = 0
	MinimaxAI.alphabeta(current_state, 2, -INF, INF, true, ai_profile, true)
	var nodes_early = MinimaxAI.node_count

	# Eksekusi AI sesungguhnya
	MinimaxAI.node_count = 0
	var start_time = Time.get_ticks_msec()

	var ai_result: Dictionary
	if use_expectimax:
		ai_result = MinimaxAI.expectimax(current_state, ai_depth, true, ai_profile, custom_move_order)
	else:
		ai_result = MinimaxAI.alphabeta(current_state, ai_depth, -INF, INF, true, ai_profile, use_alpha_beta_pruning, custom_move_order)

	var execution_time = Time.get_ticks_msec() - start_time
	var chosen_action = ai_result["action"]
	var player_hp_before = current_state.hp_player
	current_state = MinimaxAI.apply_action(current_state, chosen_action, true)

	await _play_attack_anim(current_enemy_node, chosen_action)

	if battle_ui:
		if battle_ui.has_method("update_display"):
			battle_ui.update_display(current_state)
		if battle_ui.has_method("update_debug_overlay"):
			var algo_name = "Expectimax" if use_expectimax else ("Alpha-Beta" if use_alpha_beta_pruning else "Minimax Murni")
			battle_ui.update_debug_overlay(algo_name, MinimaxAI.node_count, execution_time, ai_depth, ai_result["evals"], chosen_action)
		if battle_ui.has_method("render_comparison_table"):
			battle_ui.render_comparison_table(nodes_minimax, nodes_ab, nodes_early, ai_depth)
		if battle_ui.has_method("append_log"):
			battle_ui.append_log("NPC (" + ai_profile + ") menggunakan " + chosen_action)

	await _play_reaction_anim(current_player_node, player_hp_before, current_state.hp_player, true)

	if await check_battle_over(): return

	is_player_turn = true
	if battle_ui and battle_ui.has_method("set_player_buttons_enabled"):
		battle_ui.set_player_buttons_enabled(true)

# --- Animasi Battle ---

func _play_anim(node: Node, action_name: String) -> void:
	if node and is_instance_valid(node) and node.has_method("play_action_animation"):
		await node.play_action_animation(action_name)

func _play_attack_anim(attacker: Node, action_name: String) -> void:
	if action_name in ["ATTACK", "HEAVY_ATTACK"]:
		await _play_anim(attacker, action_name)

func _play_reaction_anim(victim: Node, hp_before, hp_after, victim_is_player: bool) -> void:
	if hp_after >= hp_before: return
	await _play_anim(victim, "DIE" if (victim_is_player and hp_after <= 0) else "HIT")

func check_battle_over() -> bool:
	if current_state.hp_player <= 0:
		if battle_ui and battle_ui.has_method("append_log"):
			battle_ui.append_log("Kekalahan! NPC memenangkan pertarungan.")
		await _end_battle_sequence("NPC")
		emit_signal("battle_ended", "NPC")
		return true
	elif current_state.hp_npc <= 0:
		if battle_ui and battle_ui.has_method("append_log"):
			battle_ui.append_log("Kemenangan! Player mengalahkan NPC.")
		await _end_battle_sequence("Player")
		emit_signal("battle_ended", "Player")
		_check_stage_clear()
		return true
	return false

func _check_stage_clear() -> void:
	await get_tree().create_timer(0.3).timeout
	var living_enemies = get_tree().get_nodes_in_group("enemies")
	var count = 0
	for e in living_enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			if "is_dying" in e and e.is_dying: continue
			count += 1

	if count == 0:
		emit_signal("stage_cleared")
		_show_stage_clear_popup()

func _show_stage_clear_popup() -> void:
	var stage_clear_node = get_tree().get_first_node_in_group("stage_clear_ui")
	if stage_clear_node and stage_clear_node.has_method("show_clear_screen"):
		stage_clear_node.show_clear_screen()
	else:
		var sc_scene = load("res://scenes/StageClearUI.tscn")
		if sc_scene:
			var sc_instance = sc_scene.instantiate()
			get_tree().root.add_child(sc_instance)
			sc_instance.show_clear_screen()

func _end_battle_sequence(winner: String) -> void:
	await get_tree().create_timer(1.0).timeout

	if battle_ui and battle_ui.has_method("show_battle_screen"):
		battle_ui.show_battle_screen(false)

	if winner == "NPC":
		if current_player_node and is_instance_valid(current_player_node):
			if current_player_node.has_method("respawn"):
				current_player_node.respawn()
			else:
				if "initial_spawn_position" in current_player_node:
					current_player_node.global_position = current_player_node.initial_spawn_position
				if current_player_node.has_method("set_battle_mode"):
					current_player_node.set_battle_mode(false)
		if current_enemy_node and is_instance_valid(current_enemy_node):
			if current_enemy_node.has_method("reset_after_battle"):
				current_enemy_node.reset_after_battle()
			else:
				current_enemy_node.is_in_battle = false
				current_enemy_node.set_physics_process(true)
	else:
		if current_player_node and is_instance_valid(current_player_node):
			if current_player_node.has_method("set_hp"):
				current_player_node.set_hp(current_state.hp_player)
			if current_player_node.has_method("set_battle_mode"):
				current_player_node.set_battle_mode(false)
		if current_enemy_node and is_instance_valid(current_enemy_node):
			if current_enemy_node.has_method("die"):
				current_enemy_node.die()
			else:
				current_enemy_node.queue_free()

# --- Eksperimen Benchmark ---

func run_all_experiments():
	print("\n=======================================================")
	print("📊 HASIL EKSPERIMEN TUBES TAHAP-2 ADVERSARIAL SEARCH")
	print("=======================================================")
	var state = MinimaxAI.BattleState.new()
	state.hp_player = 100
	state.hp_npc = 100

	print("\n--- 1. Minimax vs Alpha-Beta (Depth 5) ---")
	MinimaxAI.node_count = 0
	var t0 = Time.get_ticks_msec()
	MinimaxAI.alphabeta(state, 5, -INF, INF, true, "BALANCED", false)
	print("Minimax Murni  : Node = ", MinimaxAI.node_count, " | Waktu = ", Time.get_ticks_msec() - t0, " ms")

	MinimaxAI.node_count = 0
	t0 = Time.get_ticks_msec()
	MinimaxAI.alphabeta(state, 5, -INF, INF, true, "BALANCED", true)
	print("Alpha-Beta     : Node = ", MinimaxAI.node_count, " | Waktu = ", Time.get_ticks_msec() - t0, " ms")

	print("\n--- 2. Kedalaman Search (Depth) ---")
	for d in [2, 4, 6, 8]:
		MinimaxAI.node_count = 0
		t0 = Time.get_ticks_msec()
		MinimaxAI.alphabeta(state, d, -INF, INF, true, "BALANCED", true)
		print("Depth ", d, " : Node = ", MinimaxAI.node_count, " | Waktu = ", Time.get_ticks_msec() - t0, " ms")

	print("\n--- 3. Move Ordering (Depth 6) ---")
	var order1 = ["ATTACK", "DEFEND", "POTION", "HEAVY_ATTACK"]
	var order2 = ["POTION", "HEAVY_ATTACK", "ATTACK", "DEFEND"]
	MinimaxAI.node_count = 0
	MinimaxAI.alphabeta(state, 6, -INF, INF, true, "BALANCED", true, order1)
	print("Urutan Default [ATTACK...] : Node = ", MinimaxAI.node_count)
	MinimaxAI.node_count = 0
	MinimaxAI.alphabeta(state, 6, -INF, INF, true, "BALANCED", true, order2)
	print("Urutan Custom  [POTION...] : Node = ", MinimaxAI.node_count)

	print("\n--- 4. Profil Behavior NPC ---")
	for prof in ["BALANCED", "AGGRESSIVE", "DEFENSIVE"]:
		var res = MinimaxAI.alphabeta(state, 4, -INF, INF, true, prof, true)
		print("Profil ", prof, " -> Aksi: ", res["action"], " | Skor: ", res["evals"])

	print("\n--- 5. Alpha-Beta vs Expectimax (Depth 4) ---")
	MinimaxAI.node_count = 0
	var res_ab = MinimaxAI.alphabeta(state, 4, -INF, INF, true, "BALANCED", true)
	print("Alpha-Beta  : Best = ", res_ab["action"], " | Nodes = ", MinimaxAI.node_count)
	MinimaxAI.node_count = 0
	var res_exp = MinimaxAI.expectimax(state, 4, true, "BALANCED")
	print("Expectimax  : Best = ", res_exp["action"], " | Nodes = ", MinimaxAI.node_count)
	print("=======================================================\n")


# Helper integrasi Local Search Optimizer (Tubes Tahap 3)
func get_optimized_npc_configuration(use_simulated_annealing: bool = true, custom_player_stats: Dictionary = {}) -> Dictionary:
	var stats: Dictionary = custom_player_stats.duplicate()
	if stats.is_empty():
		var p_hp: int = 100
		if current_player_node and "hp" in current_player_node:
			p_hp = current_player_node.hp
		elif get_tree():
			var p = get_tree().get_first_node_in_group("player")
			if p and "hp" in p:
				p_hp = p.hp
		stats = {
			"hp": p_hp,
			"attack": 20,
			"defense": 5,
			"potion": 2
		}
	
	var optimizer = LocalSearchOptimizer.new()
	return optimizer.optimize_simulated_annealing(stats) if use_simulated_annealing else optimizer.optimize_hill_climbing(stats)

## Menerapkan konfigurasi NPC hasil optimasi ke battle state yang sedang aktif
func apply_optimized_npc_config_to_battle(npc_data: Dictionary) -> void:
	if not current_state:
		return
	
	var npc_type: String = String(npc_data.get("type", "Orc"))
	var default_hp: float = 100.0
	if NPCFitnessEvaluator.NPC_TYPES.has(npc_type):
		default_hp = float(NPCFitnessEvaluator.NPC_TYPES[npc_type].get("base_hp", 100.0))
	var base_hp: float = float(npc_data.get("base_hp", npc_data.get("hp", default_hp)))
	
	var items = npc_data.get("items", [])
	var item_hp: float = 0.0
	if items is Array:
		for it in items:
			var it_key: String = String(it)
			if NPCFitnessEvaluator.ITEM_CATALOG.has(it_key):
				item_hp += float(NPCFitnessEvaluator.ITEM_CATALOG[it_key].get("hp_bonus", 0.0))
	
	current_state.hp_npc = int(maxf(1.0, base_hp + item_hp))
	if battle_ui and battle_ui.has_method("update_display"):
		battle_ui.update_display(current_state)

## Benchmark komparasi performa Simulated Annealing vs Hill Climbing
func run_tahap3_optimization_experiments() -> void:
	var player_stats: Dictionary = {
		"hp": 100,
		"attack": 20,
		"defense": 5,
		"potion": 2
	}
	var optimizer = LocalSearchOptimizer.new()
	
	print("[Tubes Tahap 3] Benchmark Optimasi Konfigurasi NPC")
	var t0 = Time.get_ticks_msec()
	var sa_result = optimizer.optimize_simulated_annealing(player_stats)
	var sa_time = Time.get_ticks_msec() - t0
	print("Simulated Annealing: Fitness=%.2f | Waktu=%d ms | Iterasi=%d | Accepted Worse=%d" % [
		sa_result["best_fitness"], sa_time, sa_result["iterations"], sa_result["accepted_worse_moves"]
	])
	
	var t1 = Time.get_ticks_msec()
	var hc_result = optimizer.optimize_hill_climbing(player_stats, [], 500)
	var hc_time = Time.get_ticks_msec() - t1
	print("Hill Climbing: Fitness=%.2f | Waktu=%d ms | Iterasi=%d | Improvements=%d" % [
		hc_result["best_fitness"], hc_time, hc_result["iterations"], hc_result["improvements"]
	])


# Helper integrasi Constraint Satisfaction Problem (CSP) (Tubes Tahap 4)
func spawn_csp_enemies_in_arena(grid_manager: GridManager = null, options: Dictionary = {}) -> Array:
	var target_grid = grid_manager
	if not target_grid and get_tree():
		target_grid = get_tree().get_first_node_in_group("grid_manager")
		if not target_grid:
			var enemy = get_tree().get_first_node_in_group("enemies")
			if enemy and "grid_manager" in enemy and enemy.grid_manager:
				target_grid = enemy.grid_manager
	if target_grid and target_grid.has_method("spawn_csp_enemies"):
		return target_grid.spawn_csp_enemies(options)
	elif target_grid:
		var solver = CSPSolver.new()
		var placement = solver.solve_arena_placement(target_grid, options)
		return solver.spawn_enemies_from_csp(target_grid, self, placement)
	return []

## Benchmark komparasi CSP Backtracking (MRV + Degree + AC-3) vs Min-Conflicts Local Search
func run_tahap4_csp_experiments(grid_manager: GridManager = null, custom_options: Dictionary = {}) -> Dictionary:
	var target_grid = grid_manager
	if not target_grid and get_tree():
		target_grid = get_tree().get_first_node_in_group("grid_manager")
		if not target_grid:
			var enemy = get_tree().get_first_node_in_group("enemies")
			if enemy and "grid_manager" in enemy and enemy.grid_manager:
				target_grid = enemy.grid_manager
	var solver = CSPSolver.new()
	return solver.benchmark_csp_algorithms(target_grid, custom_options)
