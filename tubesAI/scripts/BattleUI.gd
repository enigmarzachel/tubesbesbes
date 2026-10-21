class_name BattleUI
extends CanvasLayer

var manager: BattleManager

@onready var panel_battle = get_node_or_null("Control/PanelBattle")
@onready var panel_debug = get_node_or_null("Control/PanelDebug")

@onready var lbl_player_hp = get_node_or_null("Control/PanelBattle/VBox/PlayerStats/LblPlayerHP")
@onready var lbl_npc_hp = get_node_or_null("Control/PanelBattle/VBox/NPCStats/LblNPCHP")
@onready var lbl_player_pot = get_node_or_null("Control/PanelBattle/VBox/PlayerStats/LblPlayerPot")
@onready var lbl_npc_pot = get_node_or_null("Control/PanelBattle/VBox/NPCStats/LblNPCPot")

@onready var btn_attack = get_node_or_null("Control/PanelBattle/VBox/Actions/BtnAttack")
@onready var btn_defend = get_node_or_null("Control/PanelBattle/VBox/Actions/BtnDefend")
@onready var btn_potion = get_node_or_null("Control/PanelBattle/VBox/Actions/BtnPotion")
@onready var btn_heavy = get_node_or_null("Control/PanelBattle/VBox/Actions/BtnHeavy")

@onready var txt_log = get_node_or_null("Control/PanelBattle/VBox/TxtLog")

@onready var lbl_algo = get_node_or_null("Control/PanelDebug/VBox/LblAlgo")
@onready var lbl_nodes = get_node_or_null("Control/PanelDebug/VBox/LblNodes")
@onready var lbl_time = get_node_or_null("Control/PanelDebug/VBox/LblTime")
@onready var list_evals = get_node_or_null("Control/PanelDebug/VBox/ListEvals")
@onready var table_comparison = get_node_or_null("Control/PanelDebug/VBox/TableComparison")

func _ready():
	var button_configs = [
		[btn_attack, "Attack", "ATTACK"],
		[btn_defend, "Defend", "DEFEND"],
		[btn_potion, "Potion", "POTION"],
		[btn_heavy, "Heavy", "HEAVY_ATTACK"]
	]
	for cfg in button_configs:
		var btn: Button = cfg[0]
		var label: String = cfg[1]
		var act: String = cfg[2]
		if btn:
			btn.text = label
			btn.pressed.connect(func(): if manager: manager.execute_player_action(act))

	if txt_log: txt_log.custom_minimum_size = Vector2(0, 100)
	if list_evals: list_evals.custom_minimum_size = Vector2(0, 100)
	if table_comparison: table_comparison.custom_minimum_size = Vector2(0, 150)
	visible = false

func setup_ui(battle_manager: BattleManager):
	manager = battle_manager

func show_battle_screen(is_show: bool):
	visible = is_show

func update_display(state: MinimaxAI.BattleState):
	var npc_tag = ""
	if manager:
		var algo_str = "Expectimax" if manager.use_expectimax else ("Alpha-Beta" if manager.use_alpha_beta_pruning else "Minimax")
		npc_tag = " [%s | %s]" % [manager.ai_profile, algo_str]
	if lbl_player_hp: lbl_player_hp.text = "Player HP: %d/100%s" % [state.hp_player, " (DEF)" if state.def_player else ""]
	if lbl_npc_hp: lbl_npc_hp.text = "NPC HP: %d/100%s%s" % [state.hp_npc, npc_tag, " (DEF)" if state.def_npc else ""]
	if lbl_player_pot: lbl_player_pot.text = "Potion: " + str(state.potion_player)
	if lbl_npc_pot: lbl_npc_pot.text = "Potion: " + str(state.potion_npc)
	if btn_potion: btn_potion.disabled = (state.potion_player <= 0)

func set_player_buttons_enabled(enabled: bool):
	if btn_attack: btn_attack.disabled = not enabled
	if btn_defend: btn_defend.disabled = not enabled
	if btn_heavy: btn_heavy.disabled = not enabled
	if btn_potion and manager and manager.current_state:
		btn_potion.disabled = (not enabled) or (manager.current_state.potion_player <= 0)

func update_debug_overlay(algo: String, nodes: int, time_ms: int, depth: int, evals: Dictionary, chosen_move: String):
	var prof_text = (" [" + manager.ai_profile + "]") if manager else ""
	if lbl_algo: lbl_algo.text = "Algoritma: %s%s (Depth %d)" % [algo, prof_text, depth]
	if lbl_nodes: lbl_nodes.text = "Nodes Dikunjungi: " + str(nodes)
	if lbl_time: lbl_time.text = "Waktu Komputasi: %d ms" % time_ms
	if list_evals:
		list_evals.clear()
		for act in evals:
			var text = "%s : Score %.2f%s" % [act, evals[act], " [TERPILIH]" if act == chosen_move else ""]
			list_evals.add_item(text)

func render_comparison_table(minimax_nodes: int, ab_nodes: int, early_nodes: int, depth: int):
	if not table_comparison: return

	var rows = [
		["Minimax", str(minimax_nodes), "Full (D=" + str(depth) + ")"],
		["Alpha-Beta", str(ab_nodes), "Pruned (D=" + str(depth) + ")"],
		["Early Stop", str(early_nodes), "D=2"]
	]
	var bbcode = "[table=3][cell][b] Metode [/b][/cell][cell][b] Nodes [/b][/cell][cell][b] Waktu [/b][/cell]"
	for row in rows:
		bbcode += "[cell] %s [/cell][cell] %s [/cell][cell] %s [/cell]" % row
	bbcode += "[/table]"
	table_comparison.text = bbcode

func append_log(msg: String):
	if txt_log: txt_log.text += msg + "\n"
