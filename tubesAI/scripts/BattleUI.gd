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

# Referensi Debug Overlay & Node Tabel
@onready var lbl_algo = get_node_or_null("Control/PanelDebug/VBox/LblAlgo")
@onready var lbl_nodes = get_node_or_null("Control/PanelDebug/VBox/LblNodes")
@onready var lbl_time = get_node_or_null("Control/PanelDebug/VBox/LblTime")
@onready var list_evals = get_node_or_null("Control/PanelDebug/VBox/ListEvals")
@onready var table_comparison = get_node_or_null("Control/PanelDebug/VBox/TableComparison")

func _ready():
	if btn_attack: btn_attack.pressed.connect(func(): if manager: manager.execute_player_action("ATTACK"))
	if btn_defend: btn_defend.pressed.connect(func(): if manager: manager.execute_player_action("DEFEND"))
	if btn_potion: btn_potion.pressed.connect(func(): if manager: manager.execute_player_action("POTION"))
	if btn_heavy: btn_heavy.pressed.connect(func(): if manager: manager.execute_player_action("HEAVY_ATTACK"))
	
	if btn_attack: btn_attack.text = "Attack"
	if btn_defend: btn_defend.text = "Defend"
	if btn_potion: btn_potion.text = "Potion"
	if btn_heavy: btn_heavy.text = "Heavy"
		
	if txt_log: txt_log.custom_minimum_size = Vector2(0, 100)
	if list_evals: list_evals.custom_minimum_size = Vector2(0, 100)
	if table_comparison: table_comparison.custom_minimum_size = Vector2(0, 150)
		
	visible = false

func setup_ui(battle_manager: BattleManager):
	manager = battle_manager

func show_battle_screen(is_show: bool):
	visible = is_show

func update_display(state: MinimaxAI.BattleState):
	if lbl_player_hp: lbl_player_hp.text = "Player HP: " + str(state.hp_player) + "/100" + (" (DEF)" if state.def_player else "")
	if lbl_npc_hp: lbl_npc_hp.text = "NPC HP: " + str(state.hp_npc) + "/100" + (" (DEF)" if state.def_npc else "")
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
	if lbl_algo: lbl_algo.text = "Algoritma: " + algo + " (Depth " + str(depth) + ")"
	if lbl_nodes: lbl_nodes.text = "Nodes Dikunjungi: " + str(nodes)
	if lbl_time: lbl_time.text = "Waktu Komputasi: " + str(time_ms) + " ms"
	
	if list_evals:
		list_evals.clear()
		for act in evals:
			var item_text = act + " : Score " + str(snapped(evals[act], 0.01))
			if act == chosen_move:
				item_text += " [TERPILIH]"
			list_evals.add_item(item_text)

# --- FUNGSI TAMPILAN TABEL PERBANDINGAN PERTANYAAN ---
func render_comparison_table(minimax_nodes: int, ab_nodes: int, early_nodes: int, depth: int):
	if not table_comparison:
		return
		
	var bbcode_text = "[table=3]"
	# Header Tabel
	bbcode_text += "[cell][b] Metode [/b][/cell][cell][b] Nodes [/b][/cell][cell][b] Waktu [/b][/cell]"
	
	# Baris 1: Minimax Murni
	bbcode_text += "[cell] Minimax [/cell]"
	bbcode_text += "[cell] " + str(minimax_nodes) + " [/cell]"
	bbcode_text += "[cell] Full [/cell]"
	
	# Baris 2: Alpha-Beta Pruning
	bbcode_text += "[cell] Alpha-Beta [/cell]"
	bbcode_text += "[cell] " + str(ab_nodes) + " [/cell]"
	bbcode_text += "[cell] Optimal [/cell]"
	
	# Baris 3: Early Stop (Cutoff Depth)
	bbcode_text += "[cell] Early Stop [/cell]"
	bbcode_text += "[cell] " + str(early_nodes) + " [/cell]"
	bbcode_text += "[cell] D=" + str(depth) + " [/cell]"
	
	bbcode_text += "[/table]"
	
	table_comparison.text = bbcode_text

func append_log(msg: String):
	if txt_log: txt_log.text += msg + "\n"
