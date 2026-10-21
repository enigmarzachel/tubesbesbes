extends CanvasLayer

@onready var vbox: VBoxContainer = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer")
@onready var option_algo: OptionButton = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/OptionAlgo")
@onready var option_heuristic: OptionButton = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/OptionHeuristic")
@onready var label_heuristic: Label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/LabelHeuristic")

var option_npc_profile: OptionButton
var option_npc_algo: OptionButton
var option_npc_depth: OptionButton

func _ready() -> void:
	# Setup Pathfinding
	if option_algo:
		option_algo.clear()
		option_algo.add_item("A* Search (A-Star)", 0)
		option_algo.add_item("Uniform Cost Search (UCS)", 1)
		option_algo.item_selected.connect(_on_algo_selected)

	if option_heuristic:
		option_heuristic.clear()
		option_heuristic.add_item("Manhattan", 0)
		option_heuristic.add_item("Euclidean", 1)
		option_heuristic.item_selected.connect(_on_heuristic_selected)

	_on_algo_selected(0)
	_setup_npc_mode_ui()

func _setup_npc_mode_ui() -> void:
	if not vbox: return

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
	var is_astar = (index == 0)
	Pathfinding.current_algorithm = "astar" if is_astar else "ucs"
	if option_heuristic: option_heuristic.disabled = not is_astar
	if label_heuristic: label_heuristic.modulate.a = 1.0 if is_astar else 0.5

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
