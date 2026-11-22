extends SceneTree

class MockGrid extends RefCounted:
	var cell_costs: Dictionary = {}

	func is_passable(cell: Vector2i) -> bool:
		return cell_costs.has(cell)

	func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if is_passable(cell + direction):
				result.append(cell + direction)
		return result

	func get_step_cost(cell: Vector2i) -> float:
		return float(cell_costs.get(cell, 1.0))

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		push_error("FAIL: " + description)
		failures += 1

func _run() -> void:
	_test_pathfinding()
	_test_adversarial_search()
	_test_local_search()
	_test_logic_and_planning()
	_test_menu_responsive_layout()
	await _test_menu_presentation()
	await _test_lesson_modes()
	await _test_local_spawn_integration()
	if failures == 0:
		print("AI smoke tests passed")
	quit(1 if failures > 0 else 0)

func _test_pathfinding() -> void:
	var grid := MockGrid.new()
	grid.cell_costs = {
		Vector2i(0, 0): 1.0, Vector2i(1, 0): 10.0, Vector2i(2, 0): 1.0,
		Vector2i(0, 1): 1.0, Vector2i(1, 1): 1.0, Vector2i(2, 1): 1.0
	}
	var start := Vector2i(0, 0)
	var goal := Vector2i(2, 0)
	var ucs := Pathfinding.search_path(grid, start, goal, "ucs")
	var astar_manhattan := Pathfinding.search_path(grid, start, goal, "astar", "manhattan")
	var astar_euclidean := Pathfinding.search_path(grid, start, goal, "astar", "euclidean")
	var greedy := Pathfinding.search_path(grid, start, goal, "greedy", "manhattan")
	_check(ucs.found and astar_manhattan.found and astar_euclidean.found and greedy.found, "all pathfinding strategies find reachable goal")
	_check(is_equal_approx(float(ucs.path_cost), float(astar_manhattan.path_cost)), "A* Manhattan matches UCS optimal path cost")
	_check(is_equal_approx(float(ucs.path_cost), float(astar_euclidean.path_cost)), "A* Euclidean matches UCS optimal path cost")
	_check(not Pathfinding.search_path(grid, start, Vector2i(8, 8), "astar").found, "pathfinding reports unreachable goal")

func _test_adversarial_search() -> void:
	var state := MinimaxAI.BattleState.new()
	state.hp_player = 75
	state.hp_npc = 80
	MinimaxAI.node_count = 0
	var minimax := MinimaxAI.alphabeta(state, 3, -INF, INF, true, "BALANCED", false)
	var minimax_nodes := MinimaxAI.node_count
	MinimaxAI.node_count = 0
	var alpha_beta := MinimaxAI.alphabeta(state, 3, -INF, INF, true, "BALANCED", true)
	var alpha_beta_nodes := MinimaxAI.node_count
	_check(minimax.action == alpha_beta.action and is_equal_approx(minimax.score, alpha_beta.score), "Alpha-Beta preserves Minimax decision and score")
	_check(alpha_beta_nodes <= minimax_nodes, "Alpha-Beta expands no more nodes than Minimax")
	var expectimax := MinimaxAI.expectimax(state, 2, true, "BALANCED")
	_check(MinimaxAI.get_valid_actions(state, true).has(expectimax.action), "Expectimax returns legal battle action")

func _test_local_search() -> void:
	var player_stats := {"hp": 100, "attack": 20, "defense": 5, "potion": 2}
	var initial: Array = [{"type": "Orc", "items": ["SWORD"]}]
	var initial_fitness := NPCFitnessEvaluator.evaluate_fitness(initial, player_stats)
	var optimizer := LocalSearchOptimizer.new()
	var hill := optimizer.optimize_hill_climbing(player_stats, initial, 40)
	_check(float(hill.best_fitness) >= initial_fitness, "Hill Climbing does not return a worse fitness than its initial state")
	_check(not hill.best_config.is_empty(), "Local Search returns a valid NPC configuration")

func _test_logic_and_planning() -> void:
	var facts: Array[String] = ["PLAYER_NEARBY"]
	var rules := PropositionalKnowledgeBase.get_rules()
	var inference := PropositionalInferenceEngine.infer(facts, rules)
	_check(inference.facts.has("ENGAGE_PLAYER"), "knowledge base infers solo engagement")
	var actions: Array[Dictionary] = [
		{"name": "engage", "preconditions": ["ENGAGE_PLAYER"], "add": ["TACTIC_READY"], "delete": []}
	]
	var goal: Array[String] = ["TACTIC_READY"]
	var forward := AutomatedPlanner.plan_forward(["ENGAGE_PLAYER"], [], goal, actions)
	var backward := AutomatedPlanner.plan_backward(["ENGAGE_PLAYER"], [], goal, actions)
	_check(forward.success and forward.plan == ["engage"], "forward planner reaches tactic goal")
	_check(backward.success and backward.plan == ["engage"], "backward planner regresses to valid initial facts")

func _test_menu_responsive_layout() -> void:
	var menu_script := load("res://scripts/gameplay_integration/MainMenu.gd") as Script
	var menu := menu_script.new() as Node
	var narrow: Dictionary = menu.call("_get_menu_layout", 320.0)
	var wide: Dictionary = menu.call("_get_menu_layout", 1440.0)
	_check(float(narrow.content_width) <= 296.0 and float(narrow.panel_width) <= 272.0 and int(narrow.columns) == 1, "main menu fits a narrow viewport in one column")
	_check(is_equal_approx(float(wide.content_width), 820.0) and int(wide.columns) == 2, "main menu uses a centered two-column layout on wide screens")
	menu.free()

func _test_menu_presentation() -> void:
	var menu_pack := load("res://scenes/MainMenu.tscn") as PackedScene
	_check(menu_pack != null, "main menu scene resource loads")
	if not menu_pack:
		return
	var menu := menu_pack.instantiate() as Control
	root.add_child(menu)
	await process_frame
	var material_grid := menu.find_child("MaterialGrid", true, false) as GridContainer
	_check(material_grid != null and material_grid.get_child_count() == 6, "menu separates the six course materials into their own section")
	_check(menu.find_child("ChallengeGrid", true, false) == null, "menu contains no separate challenge section")
	var sixth_card := material_grid.get_node_or_null("MaterialCard6")
	_check(sixth_card != null and sixth_card.find_children("*", "Label", true, false).size() >= 2, "each course material has a persistent explanation card")
	var has_general_objective := false
	for label in menu.find_children("*", "Label", true, false):
		if String(label.text).contains("TUJUAN DUNGEON"):
			has_general_objective = true
	_check(not has_general_objective, "menu explanation focuses on AI application, not the general game objective")
	var start_button := menu.get("start_button") as Button
	_check(start_button != null and start_button.text == "Mainkan", "menu has one clearly labeled play button")
	_check(menu.get("center_container") is CenterContainer and (menu.get("center_container") as CenterContainer).size_flags_horizontal == Control.SIZE_EXPAND_FILL, "menu panel is centered in the available viewport")
	_check(int(menu.call("_get_start_stage")) == 0, "Mainkan starts the arena with all material features available")
	menu.queue_free()
	await process_frame

func _test_local_spawn_integration() -> void:
	set_meta("selected_ai_stage", 3)
	var arena_pack := load("res://scenes/tahap_2.tscn") as PackedScene
	_check(arena_pack != null, "main arena scene loads")
	if not arena_pack:
		return
	var arena := arena_pack.instantiate()
	root.add_child(arena)
	await process_frame
	var exploration_ui := arena.find_child("PathfindingUI", true, false)
	_check(exploration_ui != null and exploration_ui.find_child("ControlsScroll", true, false) != null, "exploration controls are scrollable to prevent panel overlap")
	if exploration_ui:
		var path_report := String(exploration_ui.call("_build_pathfinding_comparison_report"))
		var combined_report := String(exploration_ui.call("_format_benchmark_results", {}, {}, {}, true, path_report))
		_check(path_report.contains("UCS") and path_report.contains("A* Manhattan") and path_report.contains("A* Euclidean") and path_report.contains("Greedy Manhattan"), "Pathfinding comparison reports all four methods")
		_check(combined_report.contains("Tahap 1 — Pathfinding") and combined_report.contains("Tahap 4"), "on-screen benchmark combines Pathfinding and later material results")
		var narrow_dialog: Vector2i = exploration_ui.call("_get_benchmark_dialog_size", Vector2(320.0, 240.0))
		_check(narrow_dialog == Vector2i(296, 216), "benchmark dialog stays inside a narrow viewport")
		exploration_ui.call("_run_ai_benchmarks")
		await process_frame
		var benchmark_view := exploration_ui.get("benchmark_results_view") as RichTextLabel
		var benchmark_dialog := exploration_ui.get("benchmark_dialog") as AcceptDialog
		_check(bool(exploration_ui.get("benchmark_has_run")) and benchmark_view != null and benchmark_dialog != null and benchmark_dialog.visible, "benchmark action runs and opens its in-game results view")
		if benchmark_view:
			_check(benchmark_view.text.contains("Tahap 1 — Pathfinding") and benchmark_view.text.contains("Tahap 2") and benchmark_view.text.contains("Tahap 3") and benchmark_view.text.contains("Tahap 4"), "full benchmark result contains all four measured topics")
		var local_method := exploration_ui.find_child("OptionLocalSearchMethod", true, false) as OptionButton
		var csp_button := exploration_ui.find_child("ButtonSpawnCSP", true, false) as Button
		_check(local_method != null and local_method.visible, "Local Search lesson exposes its method selector")
		_check(csp_button != null and not csp_button.visible, "Local Search lesson hides unrelated CSP control")
	var grid := arena as GridManager
	_check(grid != null, "arena exposes GridManager")
	if not grid:
		arena.queue_free()
		return
	var fixed_initial: Array = [{"type": "Orc", "items": ["SWORD"]}]
	var spawned := grid.spawn_optimized_npcs({}, false, fixed_initial)
	_check(not spawned.is_empty(), "Local Search spawns at least one NPC in the arena")
	if not spawned.is_empty():
		var npc: Node = spawned[0]
		_check(npc.get_script() != null and npc.get_script().resource_path == "res://scripts/week_02_agents/enemy.gd", "Local Search NPC carries the AI behavior script")
		_check(npc.is_in_group("enemies"), "Local Search NPC registers in enemies group")
		_check(npc.get("player") != null and npc.get("grid_manager") == grid and npc.get("tilemap_layer") != null, "Local Search NPC receives movement dependencies")
		var player := get_first_node_in_group("player") as Node2D
		if player:
			npc.global_position = player.global_position
			await create_timer(0.7).timeout
			_check(int(npc.get("current_state")) == 1 or bool(npc.get("is_in_battle")), "Local Search NPC detects player and begins chase")
			_check(bool(grid.get_tree().get_first_node_in_group("battle_manager").has_battle_started), "Local Search NPC reaches battle trigger")
	grid.clear_spawned_npcs()
	await process_frame
	var csp_solver := CSPSolver.new()
	var csp_benchmark := csp_solver.benchmark_csp_algorithms(grid, {"max_candidate_slots": 6, "min_enemies": 1, "max_enemies": 2, "max_duri": 1, "max_steps": 80})
	_check(int(csp_benchmark.get("shared_candidate_slots", 0)) > 0, "CSP solver comparison uses one shared candidate-slot sample")
	var csp_spawned := grid.spawn_csp_enemies()
	_check(bool(grid.last_csp_result.get("success", false)), "CSP finds a valid arena assignment")
	_check(not csp_spawned.is_empty(), "CSP assignment creates active enemy nodes")
	for npc in csp_spawned:
		if npc.is_in_group("enemies"):
			_check(npc.get_script() != null and npc.get("player") != null, "CSP NPC receives AI behavior and player reference")
			break
	arena.queue_free()
	await process_frame

func _test_lesson_modes() -> void:
	var arena_pack := load("res://scenes/tahap_2.tscn") as PackedScene
	if not arena_pack:
		return
	for lesson in range(1, 9):
		set_meta("selected_ai_stage", lesson)
		var arena := arena_pack.instantiate()
		root.add_child(arena)
		await process_frame
		var ui := arena.find_child("PathfindingUI", true, false)
		if ui:
			var local_button := ui.find_child("ButtonSpawnOptimized", true, false) as Button
			var csp_button := ui.find_child("ButtonSpawnCSP", true, false) as Button
			var path_button := ui.find_child("ButtonPathBenchmark", true, false) as Button
			var benchmark_button := ui.find_child("ButtonRunBenchmarks", true, false) as Button
			var battle_algo := ui.find_child("OptionNPCAlgo", true, false) as OptionButton
			var local_method := ui.find_child("OptionLocalSearchMethod", true, false) as OptionButton
			match lesson:
				1:
					_check(path_button.visible and not benchmark_button.visible, "lesson 1 exposes path benchmark only")
				2:
					_check(battle_algo.visible and not path_button.visible and not local_button.visible, "lesson 2 exposes adversarial controls")
				3:
					_check(local_button.visible and local_method.visible and not csp_button.visible, "lesson 3 exposes Local Search controls")
				4:
					_check(csp_button.visible and not local_button.visible and not local_method.visible, "lesson 4 exposes CSP controls")
				5, 6, 7:
					_check(not local_button.visible and not csp_button.visible, "lesson %d hides unrelated spawn controls" % lesson)
				8:
					_check(benchmark_button.visible and not path_button.visible and not local_button.visible, "lesson 8 exposes AI benchmark only")
		else:
			_check(false, "lesson %d arena includes exploration UI" % lesson)
		arena.queue_free()
		await process_frame
