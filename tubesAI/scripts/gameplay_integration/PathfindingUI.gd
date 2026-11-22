extends CanvasLayer

@onready var vbox: VBoxContainer = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer")
@onready var option_algo: OptionButton = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/OptionAlgo")
@onready var option_heuristic: OptionButton = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/OptionHeuristic")
@onready var label_heuristic: Label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/LabelHeuristic")
@onready var label_action_status: Label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/LabelActionStatus")
@onready var button_spawn_optimized: Button = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/ButtonSpawnOptimized")
@onready var button_spawn_csp: Button = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/ButtonSpawnCSP")
@onready var button_run_benchmarks: Button = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/ButtonRunBenchmarks")
@onready var button_clear_spawned: Button = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/ButtonClearSpawned")
@onready var label_npc_state: Label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/LabelNPCState")
@onready var check_path_debug: CheckButton = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/CheckPathDebug")
@onready var label_lesson_goal: Label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/LabelLessonGoal")
@onready var label_lesson_progress: Label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/LabelLessonProgress")
@onready var button_menu: Button = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/ButtonMenu")
@onready var option_local_search: OptionButton = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/OptionLocalSearchMethod")
@onready var button_path_benchmark: Button = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/ButtonPathBenchmark")

var option_npc_profile: OptionButton
var option_npc_algo: OptionButton
var option_npc_depth: OptionButton
var label_path_stats: Label
var benchmark_dialog: AcceptDialog
var benchmark_scroll: ScrollContainer
var benchmark_results_view: RichTextLabel
var benchmark_has_run := false

func _process(_delta: float) -> void:
	_update_npc_state()
	_update_lesson_progress()
	if not label_path_stats:
		return
	var debug_node = get_tree().get_first_node_in_group("pathfinding_debug")
	if debug_node and debug_node.has_method("get_latest_stats_text"):
		label_path_stats.text = debug_node.get_latest_stats_text()

func _ready() -> void:
	add_to_group("exploration_overlay")
	_wrap_controls_in_scroll()
	var main_panel := get_node_or_null("PanelContainer") as Control
	if main_panel:
		var viewport_height := get_viewport().get_visible_rect().size.y
		main_panel.offset_bottom = minf(500.0, maxf(240.0, viewport_height - 16.0))
	var lesson := int(get_tree().get_meta("selected_ai_stage", 0))
	var lesson_goals := [
		"Tujuan: kalahkan seluruh musuh dan bersihkan dungeon.",
		"TAHAP 1 • Pathfinding: dekati NPC; bandingkan UCS/A*/Greedy, heuristik, ekspansi, biaya, dan jalur.",
		"TAHAP 2 • Adversarial search: menangkan duel; amati aksi, skor, node, waktu, algoritma, dan kedalaman.",
		"TAHAP 3 • Local Search: spawn NPC; amati fitness, konfigurasi, dan bandingkan metode optimasi.",
		"TAHAP 4 • CSP: spawn susunan; amati constraint, solusi, langkah/konflik dan perbandingan solver.",
		"TAHAP 5 • Logika: dekati NPC; amati fakta awal, aturan aktif, inferensi, dan keputusan.",
		"TAHAP 6 • Planning: amati state, goal, aksi, plan maju/mundur, heuristik, serta mutex.",
		"TANTANGAN • Perilaku NPC: bertahan hidup; uji patroli, deteksi, chase, duel, dan recovery.",
		"TANTANGAN • Benchmark: jalankan perbandingan dan jelaskan trade-off serta batas tiap metode.",
	]
	if label_lesson_goal and lesson >= 0 and lesson < lesson_goals.size():
		label_lesson_goal.text = lesson_goals[lesson]
	benchmark_dialog = AcceptDialog.new()
	benchmark_dialog.title = "Hasil Benchmark AI"
	add_child(benchmark_dialog)
	benchmark_scroll = ScrollContainer.new()
	benchmark_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	benchmark_dialog.add_child(benchmark_scroll)
	benchmark_results_view = RichTextLabel.new()
	benchmark_results_view.bbcode_enabled = true
	benchmark_results_view.fit_content = true
	benchmark_results_view.scroll_active = false
	benchmark_results_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	benchmark_scroll.add_child(benchmark_results_view)
	_update_benchmark_dialog_layout()
	get_viewport().size_changed.connect(_update_benchmark_dialog_layout)
	var panel := get_node_or_null("PanelContainer") as PanelContainer
	if panel:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.055, 0.075, 0.10, 0.94)
		panel_style.border_color = Color(0.29, 0.55, 0.68, 0.85)
		panel_style.set_border_width_all(1)
		panel_style.set_corner_radius_all(6)
		panel.add_theme_stylebox_override("panel", panel_style)
	if button_run_benchmarks:
		button_run_benchmarks.tooltip_text = "Jalankan perbandingan metode dan tampilkan hasilnya di dialog ini."
	if button_spawn_optimized:
		button_spawn_optimized.pressed.connect(_spawn_optimized_npcs)
	if option_local_search:
		option_local_search.add_item("Simulated Annealing", 0)
		option_local_search.add_item("Hill Climbing", 1)
	if button_spawn_csp:
		button_spawn_csp.pressed.connect(_spawn_csp_npcs)
	if button_run_benchmarks:
		button_run_benchmarks.pressed.connect(_run_ai_benchmarks)
	if button_path_benchmark:
		button_path_benchmark.pressed.connect(_run_pathfinding_comparison)
	if button_clear_spawned:
		button_clear_spawned.pressed.connect(_clear_spawned_npcs)
	if check_path_debug:
		check_path_debug.toggled.connect(_on_path_debug_toggled)

	# Setup Pathfinding
	if option_algo:
		option_algo.clear()
		option_algo.add_item("A* Search (A-Star)", 0)
		option_algo.add_item("Uniform Cost Search (UCS)", 1)
		option_algo.add_item("Greedy Best-First", 2)
		option_algo.item_selected.connect(_on_algo_selected)

	if option_heuristic:
		option_heuristic.clear()
		option_heuristic.add_item("Manhattan", 0)
		option_heuristic.add_item("Euclidean", 1)
		option_heuristic.item_selected.connect(_on_heuristic_selected)

	_on_algo_selected(0)
	_setup_npc_mode_ui()
	if button_menu:
		button_menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	_apply_lesson_focus(lesson)

func _update_benchmark_dialog_layout() -> void:
	if not benchmark_dialog or not benchmark_scroll or not benchmark_results_view:
		return
	var dialog_size := _get_benchmark_dialog_size(get_viewport().get_visible_rect().size)
	benchmark_dialog.min_size = dialog_size
	benchmark_scroll.custom_minimum_size = Vector2(maxf(140.0, float(dialog_size.x - 40)), maxf(100.0, float(dialog_size.y - 90)))
	benchmark_results_view.custom_minimum_size.x = maxf(120.0, float(dialog_size.x - 60))

func _get_benchmark_dialog_size(viewport_size: Vector2) -> Vector2i:
	return Vector2i(
		maxi(160, mini(700, int(viewport_size.x) - 24)),
		maxi(140, mini(520, int(viewport_size.y) - 24))
	)

func _wrap_controls_in_scroll() -> void:
	if not vbox or not vbox.get_parent():
		return
	var margin := vbox.get_parent()
	var scroll := ScrollContainer.new()
	scroll.name = "ControlsScroll"
	scroll.layout_mode = 2
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 160.0
	margin.remove_child(vbox)
	margin.add_child(scroll)
	scroll.add_child(vbox)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _apply_lesson_focus(lesson: int) -> void:
	if lesson == 0:
		return
	var path_controls := ["LabelAlgo", "OptionAlgo", "LabelHeuristic", "OptionHeuristic", "LabelPathStats", "CheckPathDebug", "ButtonPathBenchmark"]
	var spawn_controls := ["LabelAIExperiments", "ButtonSpawnOptimized", "ButtonSpawnCSP", "ButtonClearSpawned", "OptionLocalSearchMethod"]
	var battle_controls := ["LabelNPCProfile", "OptionNPCProfile", "LabelNPCAlgo", "OptionNPCAlgo", "LabelNPCDepth", "OptionNPCDepth"]
	var root := vbox
	if not root:
		return
	if lesson in [2, 3, 4, 5, 6]:
		for node_name in path_controls:
			var node := root.get_node_or_null(node_name)
			if node: node.visible = false
	if lesson in [1, 2, 5, 6, 7]:
		for node_name in spawn_controls:
			var node := root.get_node_or_null(node_name)
			if node: node.visible = false
	if lesson in [1, 3, 4, 5, 6, 7]:
		for node_name in battle_controls:
			var node := root.get_node_or_null(node_name)
			if node: node.visible = false
	if lesson == 3:
		var local_method := root.get_node_or_null("OptionLocalSearchMethod")
		if local_method: local_method.visible = true
		var csp_button := root.get_node_or_null("ButtonSpawnCSP")
		if csp_button: csp_button.visible = false
		var benchmark_button := root.get_node_or_null("ButtonRunBenchmarks")
		if benchmark_button: benchmark_button.visible = false
	if lesson == 4:
		var local_button := root.get_node_or_null("ButtonSpawnOptimized")
		if local_button: local_button.visible = false
		var benchmark_button := root.get_node_or_null("ButtonRunBenchmarks")
		if benchmark_button: benchmark_button.visible = false
	if lesson in [1, 2, 5, 6, 7]:
		var benchmark_button := root.get_node_or_null("ButtonRunBenchmarks")
		if benchmark_button: benchmark_button.visible = false
	if lesson == 8:
		for node_name in path_controls + spawn_controls + battle_controls:
			var node := root.get_node_or_null(node_name)
			if node: node.visible = false
	if lesson == 1:
		var path_benchmark := root.get_node_or_null("ButtonPathBenchmark")
		if path_benchmark: path_benchmark.visible = true

func _run_pathfinding_comparison() -> void:
	var report := _build_pathfinding_comparison_report()
	benchmark_results_view.text = report
	benchmark_dialog.title = "Perbandingan Pathfinding"
	benchmark_dialog.popup_centered_ratio(0.85)
	if label_action_status:
		label_action_status.text = "Perbandingan Pathfinding ditampilkan di layar."

func _build_pathfinding_comparison_report() -> String:
	var grid := _get_grid_manager()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not grid or not player or not grid.lantai:
		return "[b]Tahap 1 — Pathfinding[/b]\nTidak dapat dijalankan: player atau arena belum siap."
	var enemies := get_tree().get_nodes_in_group("enemies")
	var target: Node2D = null
	var nearest_distance := INF
	for candidate in enemies:
		if not is_instance_valid(candidate) or not (candidate is Node2D): continue
		var distance := _get_ground_position(player).distance_squared_to(_get_ground_position(candidate as Node2D))
		if distance < nearest_distance:
			nearest_distance = distance
			target = candidate
	if not target:
		return "[b]Tahap 1 — Pathfinding[/b]\nTidak dapat dijalankan: NPC tidak ditemukan."
	var layer: TileMapLayer = grid.lantai
	var start := layer.local_to_map(layer.to_local(_get_ground_position(target)))
	var goal := layer.local_to_map(layer.to_local(_get_ground_position(player)))
	var cases: Array[Dictionary] = [
		{"name": "UCS", "algorithm": "ucs", "heuristic": "manhattan"},
		{"name": "A* Manhattan", "algorithm": "astar", "heuristic": "manhattan"},
		{"name": "A* Euclidean", "algorithm": "astar", "heuristic": "euclidean"},
		{"name": "Greedy Manhattan", "algorithm": "greedy", "heuristic": "manhattan"},
	]
	var lines: Array[String] = ["[b]Tahap 1 — Pathfinding: state awal dan goal yang sama[/b]", "Awal %s → goal %s" % [str(start), str(goal)], ""]
	for test_case in cases:
		var started := Time.get_ticks_usec()
		var result: Dictionary = Pathfinding.search_path(grid, start, goal, test_case.algorithm, test_case.heuristic)
		var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
		var cost := "∞" if result.get("path_cost", null) == null else "%.1f" % float(result.path_cost)
		lines.append("[b]%s[/b] | ditemukan: %s | node: %d | biaya: %s | waktu: %.3f ms" % [test_case.name, "ya" if result.found else "tidak", result.expanded_nodes, cost, elapsed_ms])
	return "\n".join(lines)

func _get_ground_position(actor: Node2D) -> Vector2:
	for child in actor.get_children():
		if child is CollisionShape2D:
			return child.global_position
	return actor.global_position

func _update_lesson_progress() -> void:
	if not label_lesson_progress:
		return
	var lesson := int(get_tree().get_meta("selected_ai_stage", 0))
	var evidence := false
	var message := "Belum ada aktivitas pembuktian."
	var grid := _get_grid_manager()
	match lesson:
		1:
			var debug: Node = get_tree().get_first_node_in_group("pathfinding_debug")
			evidence = debug != null and debug.has_method("has_successful_path") and bool(debug.call("has_successful_path"))
			message = "Path ditemukan dan statistik pencarian terekam." if evidence else "Dekati NPC hingga ia mulai mencari jalur."
		2:
			var battle := _get_battle_manager()
			evidence = battle != null and battle.has_battle_started
			message = "Duel aktif/tercatat; amati evaluasi aksi dan node." if evidence else "Mulai duel dengan mendekati NPC."
		3:
			evidence = _count_spawned("NPC_") > 0
			message = "Konfigurasi Local Search sudah di-spawn." if evidence else "Tekan Spawn NPC (Local Search)."
		4:
			evidence = grid != null and grid.last_csp_result.get("success", false) and _count_spawned("CSP_NPC_") > 0
			message = "CSP menemukan susunan valid." if evidence else "Jalankan Spawn NPC (CSP)."
		5:
			var logic := get_tree().get_first_node_in_group("logic_inference_overlay")
			evidence = logic != null and logic.has_inference
			message = "Fakta dan hasil inferensi ditampilkan." if evidence else "Dekati NPC untuk memicu inferensi."
		6:
			var planning_logic := get_tree().get_first_node_in_group("logic_inference_overlay")
			evidence = planning_logic != null and planning_logic.has_successful_plan
			message = "Planner menghasilkan rencana non-kosong." if evidence else "Dekati NPC yang punya ally agar aksi prasyarat planning terpenuhi."
		7:
			evidence = _npc_has_chased_or_fought()
			message = "NPC telah mengejar atau memulai duel." if evidence else "Amati NPC hingga deteksi player."
		8:
			evidence = benchmark_has_run
			message = "Benchmark dijalankan; bandingkan metriknya." if evidence else "Tekan tombol Benchmark."
		_:
			evidence = get_tree().get_nodes_in_group("enemies").is_empty()
			message = "Dungeon bersih!" if evidence else "Kalahkan semua musuh untuk membersihkan dungeon."
	label_lesson_progress.text = ("BUKTI TERCATAT ✓  " if evidence else "LANGKAH BERIKUTNYA  ") + message

func _count_spawned(prefix: String) -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.name.begins_with(prefix): count += 1
	return count

func _npc_has_chased_or_fought() -> bool:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and (int(enemy.get("current_state")) == 1 or bool(enemy.get("is_in_battle"))): return true
	return false

func _setup_npc_mode_ui() -> void:
	if not vbox: return
	label_path_stats = vbox.get_node_or_null("LabelPathStats") as Label

	option_npc_profile = vbox.get_node_or_null("OptionNPCProfile") as OptionButton
	option_npc_algo = vbox.get_node_or_null("OptionNPCAlgo") as OptionButton
	option_npc_depth = vbox.get_node_or_null("OptionNPCDepth") as OptionButton

	# Fallback pembuatan kontrol jika node belum ada di scene cache
	if not option_npc_profile:
		vbox.add_child(HSeparator.new())
		var l_prof = Label.new()
		l_prof.text = "⚔️ Profil NPC:"
		l_prof.add_theme_font_size_override("font_size", 12)
		vbox.add_child(l_prof)
		option_npc_profile = OptionButton.new()
		option_npc_profile.add_theme_font_size_override("font_size", 12)
		vbox.add_child(option_npc_profile)

	if not option_npc_algo:
		var l_algo = Label.new()
		l_algo.text = "Algoritma Battle NPC:"
		l_algo.add_theme_font_size_override("font_size", 12)
		vbox.add_child(l_algo)
		option_npc_algo = OptionButton.new()
		option_npc_algo.add_theme_font_size_override("font_size", 12)
		vbox.add_child(option_npc_algo)

	if not option_npc_depth:
		var l_dep = Label.new()
		l_dep.text = "Search Depth:"
		l_dep.add_theme_font_size_override("font_size", 12)
		vbox.add_child(l_dep)
		option_npc_depth = OptionButton.new()
		option_npc_depth.add_theme_font_size_override("font_size", 12)
		vbox.add_child(option_npc_depth)

	# Inisialisasi item pilihan profil
	option_npc_profile.clear()
	option_npc_profile.add_item("Balanced (Seimbang)", 0)
	option_npc_profile.add_item("Aggressive (Agresif)", 1)
	option_npc_profile.add_item("Defensive (Bertahan)", 2)
	option_npc_profile.item_selected.connect(_on_npc_profile_selected)

	# Inisialisasi item pilihan algoritma battle
	option_npc_algo.clear()
	option_npc_algo.add_item("Alpha-Beta Pruning", 0)
	option_npc_algo.add_item("Minimax Murni", 1)
	option_npc_algo.add_item("Expectimax (Probabilistik)", 2)
	option_npc_algo.item_selected.connect(_on_npc_algo_selected)

	# Inisialisasi item pilihan depth
	option_npc_depth.clear()
	option_npc_depth.add_item("Depth 2 (Cepat)", 0)
	option_npc_depth.add_item("Depth 4 (Normal)", 1)
	option_npc_depth.add_item("Depth 6 (Smart)", 2)
	option_npc_depth.select(1) # Default depth 4
	option_npc_depth.item_selected.connect(_on_npc_depth_selected)

	_apply_to_battle_manager()

func _on_algo_selected(index: int) -> void:
	match index:
		0:
			Pathfinding.current_algorithm = "astar"
			if option_heuristic: option_heuristic.disabled = false
			if label_heuristic: label_heuristic.modulate.a = 1.0
		1:
			Pathfinding.current_algorithm = "ucs"
			if option_heuristic: option_heuristic.disabled = true
			if label_heuristic: label_heuristic.modulate.a = 0.5
		2:
			Pathfinding.current_algorithm = "greedy"
			if option_heuristic: option_heuristic.disabled = false
			if label_heuristic: label_heuristic.modulate.a = 1.0

func _on_heuristic_selected(index: int) -> void:
	Pathfinding.current_heuristic = "manhattan" if index == 0 else "euclidean"

func _on_npc_profile_selected(index: int) -> void:
	var bm = _get_battle_manager()
	if not bm: return
	match index:
		0: bm.set_ai_profile("BALANCED")
		1: bm.set_ai_profile("AGGRESSIVE")
		2: bm.set_ai_profile("DEFENSIVE")

func _on_npc_algo_selected(index: int) -> void:
	var bm = _get_battle_manager()
	if not bm: return
	match index:
		0: bm.set_ai_method("ALPHA_BETA")
		1: bm.set_ai_method("MINIMAX")
		2: bm.set_ai_method("EXPECTIMAX")

func _on_npc_depth_selected(index: int) -> void:
	var bm = _get_battle_manager()
	if not bm: return
	match index:
		0: bm.set_ai_depth(2)
		1: bm.set_ai_depth(4)
		2: bm.set_ai_depth(6)

func _apply_to_battle_manager() -> void:
	if option_npc_profile: _on_npc_profile_selected(option_npc_profile.selected)
	if option_npc_algo: _on_npc_algo_selected(option_npc_algo.selected)
	if option_npc_depth: _on_npc_depth_selected(option_npc_depth.selected)

func _get_battle_manager() -> BattleManager:
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if bm is BattleManager:
		return bm
	return get_tree().root.find_child("Node", true, false) as BattleManager

func _get_grid_manager() -> GridManager:
	var grid = get_tree().get_first_node_in_group("grid_manager")
	return grid as GridManager

func _spawn_optimized_npcs() -> void:
	var grid = _get_grid_manager()
	if not grid:
		if label_action_status: label_action_status.text = "Grid tidak ditemukan."
		return
	var use_sa := not option_local_search or option_local_search.selected == 0
	# Titik awal tetap supaya eksperimen HC dan SA bisa dibandingkan dengan kondisi awal sama.
	var shared_initial_config: Array = [{"type": "Orc", "items": ["SWORD"]}]
	var spawned = grid.spawn_optimized_npcs({}, use_sa, shared_initial_config)
	if label_action_status:
		if not grid.last_spawn_error.is_empty():
			label_action_status.text = grid.last_spawn_error
		else:
			var method_name := "Simulated Annealing" if use_sa else "Hill Climbing"
			var result: Dictionary = grid.last_optimization_result
			label_action_status.text = "%s: %d NPC | fitness %.1f → %.1f | iterasi %d" % [method_name, spawned.size(), float(result.get("initial_fitness", 0.0)), float(result.get("best_fitness", 0.0)), int(result.get("iterations", 0))]

func _clear_spawned_npcs() -> void:
	var grid := _get_grid_manager()
	if grid:
		var removed := grid.clear_spawned_npcs()
		if label_action_status:
			label_action_status.text = "%d NPC hasil spawn dihapus." % removed

func _update_npc_state() -> void:
	if not label_npc_state:
		return
	var closest: Node = null
	var best_distance := INF
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		label_npc_state.text = "Status NPC: player tidak ditemukan"
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var distance := player.global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			closest = enemy
	if not closest:
		label_npc_state.text = "Status NPC: belum ada"
		return
	var state := "Patroli"
	if closest.get("is_in_battle"):
		state = "Bertarung"
	elif closest.get("current_state") == 1:
		state = "Mengejar"
	elif closest.get("current_state") == 2:
		state = "Kembali ke posisi awal"
	label_npc_state.text = "NPC terdekat: %s (%s)" % [closest.name, state]

func _on_path_debug_toggled(enabled: bool) -> void:
	var debug_node := get_tree().get_first_node_in_group("pathfinding_debug")
	if debug_node and "show_debug" in debug_node:
		debug_node.show_debug = enabled
		if not enabled and debug_node.has_method("clear_all_enemy_debug"):
			debug_node.clear_all_enemy_debug()

func _spawn_csp_npcs() -> void:
	var grid = _get_grid_manager()
	if not grid:
		if label_action_status: label_action_status.text = "Grid tidak ditemukan."
		return
	var spawned = grid.spawn_csp_enemies()
	var result = grid.last_csp_result
	if label_action_status:
		if result.get("success", false):
			var summary = result.get("summary", {})
			label_action_status.text = "CSP: %d NPC, %d duri." % [summary.get("enemy_count", spawned.size()), summary.get("duri_count", 0)]
		else:
			label_action_status.text = "CSP tidak menemukan susunan valid: " + str(result.get("error", "constraint tidak terpenuhi"))

func _run_ai_benchmarks() -> void:
	var manager = _get_battle_manager()
	var grid = _get_grid_manager()
	if not manager:
		if label_action_status: label_action_status.text = "Battle manager tidak ditemukan."
		return
	var stage2: Dictionary = manager.run_all_experiments()
	var stage3: Dictionary = manager.run_tahap3_optimization_experiments()
	var stage4: Dictionary = {}
	if grid:
		stage4 = manager.run_tahap4_csp_experiments(grid)
	var pathfinding_report := _build_pathfinding_comparison_report()
	var report := _format_benchmark_results(stage2, stage3, stage4, grid != null, pathfinding_report)
	benchmark_has_run = true
	benchmark_results_view.text = report
	benchmark_dialog.popup_centered_ratio(0.85)
	if label_action_status:
		label_action_status.text = "Benchmark selesai; hasil ditampilkan di layar."

func _format_benchmark_results(stage2: Dictionary, stage3: Dictionary, stage4: Dictionary, has_grid: bool, pathfinding_report: String = "") -> String:
	var lines: Array[String] = ["[b]Benchmark AI[/b] — state uji sama dalam setiap perbandingan.", "[color=#aab9c8]Gulir untuk melihat semua hasil.[/color]", ""]
	lines.append(pathfinding_report if not pathfinding_report.is_empty() else "[b]Tahap 1 — Pathfinding[/b]\nBelum tersedia.")
	lines.append("")
	for stage in [stage2, stage3]:
		lines.append("[b]%s[/b]" % String(stage.get("title", "Benchmark")))
		for record in stage.get("results", []):
			lines.append("[color=#8fe0d4]● %s[/color]" % String(record.get("name", "Eksperimen")))
			for key in record:
				if key == "name": continue
				lines.append("   %s  %s" % [String(key).replace("_", " ").capitalize(), str(record[key])])
		lines.append("")
	if has_grid:
		lines.append("[b]%s[/b]" % String(stage4.get("title", "Tahap 4 — CSP")))
		lines.append("Kandidat bersama untuk kedua solver: %d slot." % int(stage4.get("shared_candidate_slots", 0)))
		for key in ["backtracking", "min_conflicts"]:
			var result: Dictionary = stage4.get(key, {})
			lines.append("[color=#8fe0d4]● %s[/color]" % key.replace("_", " ").capitalize())
			for metric in ["success", "time_ms", "steps", "conflicts", "summary", "error"]:
				if result.has(metric):
					lines.append("   %s  %s" % [metric.replace("_", " ").capitalize(), str(result[metric])])
	else:
		lines.append("[color=#f1c66d]Tahap 4 — CSP: grid tidak ditemukan; benchmark dilewati.[/color]")
	return "\n".join(lines)
