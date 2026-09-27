# PathfindingUI.gd
extends CanvasLayer

@onready var option_algo: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/OptionAlgo
@onready var option_heuristic: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/OptionHeuristic
@onready var label_heuristic: Label = $PanelContainer/MarginContainer/VBoxContainer/LabelHeuristic

func _ready() -> void:
	# 1. Isi Pilihan Algoritma
	option_algo.clear()
	option_algo.add_item("A* Search (A-Star)", 0)
	option_algo.add_item("Uniform Cost Search (UCS)", 1)
	option_algo.item_selected.connect(_on_algo_selected)

	# 2. Isi Pilihan Heuristik
	option_heuristic.clear()
	option_heuristic.add_item("Manhattan", 0)
	option_heuristic.add_item("Euclidean", 1)
	option_heuristic.item_selected.connect(_on_heuristic_selected)

	# Set default awal
	_on_algo_selected(0)

func _on_algo_selected(index: int) -> void:
	if index == 0:
		Pathfinding.current_algorithm = "astar"
		# A* membutuhkan Heuristik
		option_heuristic.disabled = false
		label_heuristic.modulate.a = 1.0
	else:
		Pathfinding.current_algorithm = "ucs"
		# UCS tidak menggunakan Heuristik (nonaktifkan UI heuristik)
		option_heuristic.disabled = true
		label_heuristic.modulate.a = 0.5

func _on_heuristic_selected(index: int) -> void:
	if index == 0:
		Pathfinding.current_heuristic = "manhattan"
	else:
		Pathfinding.current_heuristic = "euclidean"
