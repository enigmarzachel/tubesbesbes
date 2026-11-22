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
	_style_panel(panel_battle, Color(0.055, 0.075, 0.10, 0.94), Color(0.29, 0.55, 0.68, 0.85))
	_style_panel(panel_debug, Color(0.045, 0.06, 0.085, 0.96), Color(0.25, 0.78, 0.72, 0.9))
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

	if txt_log: txt_log.custom_minimum_size = Vector2(0, 90)
	if list_evals: list_evals.custom_minimum_size = Vector2(0, 72)
	if table_comparison:
		table_comparison.custom_minimum_size = Vector2(320, 88)
		table_comparison.fit_content = false
		table_comparison.add_theme_font_size_override("normal_font_size", 12)
	for button in [btn_attack, btn_defend, btn_potion, btn_heavy]:
		if button:
			button.custom_minimum_size.y = 42
			button.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98))
			button.add_theme_color_override("font_disabled_color", Color(0.48, 0.52, 0.57))
	visible = false

func _style_panel(target: Control, background: Color, border: Color) -> void:
	if not target:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	target.add_theme_stylebox_override("panel", style)

func setup_ui(battle_manager: BattleManager):
	manager = battle_manager

func show_battle_screen(is_show: bool):
	visible = is_show

func update_display(state: MinimaxAI.BattleState):
	var npc_tag = ""
	if manager:
		var algo_str = "Expectimax" if manager.use_expectimax else ("Alpha-Beta" if manager.use_alpha_beta_pruning else "Minimax")
		npc_tag = " [%s | %s]" % [manager.ai_profile, algo_str]
	if lbl_player_hp: lbl_player_hp.text = "Player HP: %d/%d%s" % [state.hp_player, state.max_hp_player, " (DEF)" if state.def_player else ""]
	if lbl_npc_hp: lbl_npc_hp.text = "NPC HP: %d/%d%s%s" % [state.hp_npc, state.max_hp_npc, npc_tag, " (DEF)" if state.def_npc else ""]
	if lbl_player_hp: lbl_player_hp.modulate = _health_color(state.hp_player, state.max_hp_player)
	if lbl_npc_hp: lbl_npc_hp.modulate = _health_color(state.hp_npc, state.max_hp_npc)
	if lbl_player_pot: lbl_player_pot.text = "Potion: " + str(state.potion_player)
	if lbl_npc_pot: lbl_npc_pot.text = "Potion: " + str(state.potion_npc)
	if btn_potion: btn_potion.disabled = (state.potion_player <= 0)

func set_player_buttons_enabled(enabled: bool):
	if btn_attack: btn_attack.disabled = not enabled
	if btn_defend: btn_defend.disabled = not enabled
	if btn_heavy: btn_heavy.disabled = not enabled
	if btn_potion and manager and manager.current_state:
		btn_potion.disabled = (not enabled) or (manager.current_state.potion_player <= 0)

func update_debug_overlay(algo: String, nodes: int, time_ms: float, depth: int, evals: Dictionary, chosen_move: String):
	var prof_text = (" [" + manager.ai_profile + "]") if manager else ""
	if lbl_algo: lbl_algo.text = "Algoritma: %s%s (Depth %d)" % [algo, prof_text, depth]
	if lbl_nodes: lbl_nodes.text = "Nodes Dikunjungi: " + str(nodes)
	if lbl_time: lbl_time.text = "Waktu Komputasi: %.3f ms" % time_ms
	if list_evals:
		list_evals.clear()
		for act in evals:
			var text = "%s : Score %.2f%s" % [act, evals[act], " [TERPILIH]" if act == chosen_move else ""]
			var index: int = list_evals.add_item(text)
			if act == chosen_move:
				list_evals.set_item_custom_fg_color(index, Color(0.42, 0.95, 0.67))
			else:
				list_evals.set_item_custom_fg_color(index, Color(0.82, 0.86, 0.91))

func render_comparison_table(
	minimax_nodes: int, minimax_time_ms: float,
	ab_nodes: int, ab_time_ms: float,
	depth2_nodes: int, depth2_time_ms: float,
	depth: int
):
	if not table_comparison: return

	var rows = [
		["Minimax", str(minimax_nodes), "%.3f ms" % minimax_time_ms],
		["Alpha-Beta", str(ab_nodes), "%.3f ms" % ab_time_ms],
		["Cutoff ≤500", str(depth2_nodes), "%.3f ms" % depth2_time_ms]
	]
	var bbcode = "[b]Depth %d[/b]\n[table=3][cell][b]Metode[/b][/cell][cell][b]Node[/b][/cell][cell][b]Waktu[/b][/cell]" % depth
	for row in rows:
		bbcode += "[cell] %s [/cell][cell] %s [/cell][cell] %s [/cell]" % row
	bbcode += "[/table]"
	table_comparison.text = bbcode

func _health_color(hp: int, max_hp: int) -> Color:
	var ratio := float(hp) / float(maxi(1, max_hp))
	if ratio <= 0.3:
		return Color(1.0, 0.42, 0.38)
	if ratio <= 0.6:
		return Color(1.0, 0.78, 0.35)
	return Color(0.76, 0.96, 0.82)

func append_log(msg: String):
	if txt_log: txt_log.text += msg + "\n"
