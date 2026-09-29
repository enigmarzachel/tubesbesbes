class_name BattleManager
extends Node

signal battle_ended(winner_name: String)

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
	if battle_ui_path:
		battle_ui = get_node_or_null(battle_ui_path)

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
	# Player battle dengan HP yang dimiliki sebelum battle (setelah kena duri, dll)
	if current_player_node and "hp" in current_player_node:
		current_state.hp_player = current_player_node.hp
	else:
		current_state.hp_player = 100
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
	
	# 1. Player memainkan animasi serangan (attack / heavy)
	await _play_attack_anim(current_player_node, action_name)
	
	# 2. HP turun saat serangan mengenai
	if battle_ui and battle_ui.has_method("update_display"):
		battle_ui.update_display(current_state)
		battle_ui.append_log("Player menggunakan " + action_name)
	
	# 3. Musuh bereaksi (hit) kalau HP-nya berkurang
	await _play_reaction_anim(current_enemy_node, npc_hp_before, current_state.hp_npc, false)
		
	if check_battle_over(): return
	
	await get_tree().create_timer(0.6).timeout
	execute_npc_turn()

func execute_npc_turn():
	MinimaxAI.node_count = 0
	MinimaxAI.alphabeta(current_state, ai_depth, -INF, INF, true, ai_profile, false)
	var nodes_minimax = MinimaxAI.node_count
	
	MinimaxAI.node_count = 0
	MinimaxAI.alphabeta(current_state, ai_depth, -INF, INF, true, ai_profile, true)
	var nodes_ab = MinimaxAI.node_count
	
	MinimaxAI.node_count = 0
	MinimaxAI.alphabeta(current_state, 2, -INF, INF, true, ai_profile, true)
	var nodes_early = MinimaxAI.node_count

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
	
	# NPC memainkan animasi serangan (attack / heavy)
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
	
	# Player bereaksi: hit, atau mati kalau HP habis
	await _play_reaction_anim(current_player_node, player_hp_before, current_state.hp_player, true)
			
	if check_battle_over(): return
	
	is_player_turn = true
	if battle_ui and battle_ui.has_method("set_player_buttons_enabled"):
		battle_ui.set_player_buttons_enabled(true)

# --- ANIMASI BATTLE ---
func _play_anim(node: Node, action_name: String) -> void:
	if node and is_instance_valid(node) and node.has_method("play_action_animation"):
		await node.play_action_animation(action_name)

func _play_attack_anim(attacker: Node, action_name: String) -> void:
	if action_name == "ATTACK" or action_name == "HEAVY_ATTACK":
		await _play_anim(attacker, action_name)

func _play_reaction_anim(victim: Node, hp_before, hp_after, victim_is_player: bool) -> void:
	if hp_after >= hp_before:
		return # tidak kena damage (mis. DEFEND menahan semua / POTION)
	if victim_is_player and hp_after <= 0:
		await _play_anim(victim, "DIE")
	else:
		await _play_anim(victim, "HIT")

func check_battle_over() -> bool:
	if current_state.hp_player <= 0:
		if battle_ui and battle_ui.has_method("append_log"):
			battle_ui.append_log("Kekalahan! NPC memenangkan pertarungan.")
		emit_signal("battle_ended", "NPC")
		_end_battle_sequence("NPC")
		return true
	elif current_state.hp_npc <= 0:
		if battle_ui and battle_ui.has_method("append_log"):
			battle_ui.append_log("Kemenangan! Player mengalahkan NPC.")
		emit_signal("battle_ended", "Player")
		_end_battle_sequence("Player")
		return true
	return false

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
			# Sisa HP setelah menang dibawa keluar battle
			if current_player_node.has_method("set_hp"):
				current_player_node.set_hp(current_state.hp_player)
			if current_player_node.has_method("set_battle_mode"):
				current_player_node.set_battle_mode(false)
				
		if current_enemy_node and is_instance_valid(current_enemy_node):
			if current_enemy_node.has_method("die"):
				current_enemy_node.die()
			else:
				current_enemy_node.queue_free()

func run_all_experiments():
	print("\n=======================================================")
	print("📊 HASIL EKSPERIMEN TUBES TAHAP-2 ADVERSARIAL SEARCH")
	print("=======================================================")
	var state = MinimaxAI.BattleState.new()
	state.hp_player = 100
	state.hp_npc = 100
	
	print("\n--- 1. Perbandingan Minimax vs Alpha-Beta (Depth 5) ---")
	MinimaxAI.node_count = 0
	var t0 = Time.get_ticks_msec()
	MinimaxAI.alphabeta(state, 5, -INF, INF, true, "BALANCED", false)
	print("Minimax Murni  : Node = ", MinimaxAI.node_count, " | Waktu = ", Time.get_ticks_msec() - t0, " ms")
	
	MinimaxAI.node_count = 0
	t0 = Time.get_ticks_msec()
	MinimaxAI.alphabeta(state, 5, -INF, INF, true, "BALANCED", true)
	print("Alpha-Beta     : Node = ", MinimaxAI.node_count, " | Waktu = ", Time.get_ticks_msec() - t0, " ms")
	
	print("\n--- 2. Perbandingan Kedalaman Search (Depth) ---")
	for d in [2, 4, 6, 8]:
		MinimaxAI.node_count = 0
		t0 = Time.get_ticks_msec()
		MinimaxAI.alphabeta(state, d, -INF, INF, true, "BALANCED", true)
		print("Depth ", d, " : Node = ", MinimaxAI.node_count, " | Waktu = ", Time.get_ticks_msec() - t0, " ms")
		
	print("\n--- 3. Perbandingan Move Ordering (Depth 6) ---")
	var order1 = ["ATTACK", "DEFEND", "POTION", "HEAVY_ATTACK"]
	var order2 = ["POTION", "HEAVY_ATTACK", "ATTACK", "DEFEND"]
	MinimaxAI.node_count = 0
	MinimaxAI.alphabeta(state, 6, -INF, INF, true, "BALANCED", true, order1)
	print("Urutan Default [ATTACK...] : Node = ", MinimaxAI.node_count)
	MinimaxAI.node_count = 0
	MinimaxAI.alphabeta(state, 6, -INF, INF, true, "BALANCED", true, order2)
	print("Urutan Custom  [POTION...] : Node = ", MinimaxAI.node_count)

	print("\n--- 4. Perbandingan Profil Behavior NPC (Evaluasi Aksi) ---")
	for prof in ["BALANCED", "AGGRESSIVE", "DEFENSIVE"]:
		var res = MinimaxAI.alphabeta(state, 4, -INF, INF, true, prof, true)
		print("Profil ", prof, " -> Aksi Terpilih: ", res["action"], " | Skor Evaluasi: ", res["evals"])

	print("\n--- 5. Perbandingan Alpha-Beta vs Expectimax (Depth 4) ---")
	MinimaxAI.node_count = 0
	var res_ab = MinimaxAI.alphabeta(state, 4, -INF, INF, true, "BALANCED", true)
	print("Alpha-Beta  : Best Move = ", res_ab["action"], " | Nodes = ", MinimaxAI.node_count)
	MinimaxAI.node_count = 0
	var res_exp = MinimaxAI.expectimax(state, 4, true, "BALANCED")
	print("Expectimax  : Best Move = ", res_exp["action"], " | Nodes = ", MinimaxAI.node_count)
	print("=======================================================\n")
