extends Control

const GAME_SCENE := "res://scenes/tahap_2.tscn"
const LESSONS := [
	["Tahap 1 · Pathfinding", "NPC mencari jalur. Amati UCS, A*, heuristik, node ekspansi, biaya, dan jalur."],
	["Tahap 2 · Minimax", "Duel turn-based. Bandingkan Minimax, Alpha-Beta, Expectimax, dan kedalaman."],
	["Tahap 3 · Local Search", "Spawn konfigurasi NPC; amati fitness dan bandingkan Hill Climbing dengan Simulated Annealing."],
	["Tahap 4 · CSP", "Spawn susunan NPC/duri; amati constraint, Backtracking, dan Min-Conflicts."],
	["Tahap 5 · Logika", "Dekati NPC sendiri/bersama ally; amati fakta, aturan, inferensi, dan keputusan."],
	["Tahap 6 · Planning", "Amati state, goal, aksi, plan maju/mundur, heuristik, dan mutex."],
]
const DETAILS := [
	"Pertanyaan: jalur mana yang membawa NPC ke player?\nMetode: UCS memilih biaya kumulatif terendah; A* mengurutkan g(n)+h(n); Greedy hanya memakai h(n).\nBukti: sukses/gagal, jalur, node diekspansi, biaya, waktu. Coba Manhattan dan Euclidean.",
	"Model: state berisi HP, potion, dan defend; aksi meliputi serang, heavy attack, defend, potion.\nMetode: Minimax mencari respons optimal dua pihak; Alpha-Beta memangkas cabang; Expectimax memasukkan peluang.\nBukti: aksi terpilih, skor aksi, node, waktu, kedalaman.",
	"State: konfigurasi NPC dan item; fitness mengukur kedekatan total combat power NPC dengan player.\nMetode: Hill Climbing mengambil tetangga terbaik yang membaik; Simulated Annealing kadang menerima langkah lebih buruk.\nBukti: gunakan titik awal sama, bandingkan fitness awal/akhir, iterasi, dan waktu.",
	"Variabel: slot arena. Domain: NPC, duri, atau kosong. Constraint: tile valid, jarak, jumlah, dan batas kekuatan.\nMetode: Backtracking mencari assignment konsisten; Min-Conflicts memperbaiki konflik secara iteratif.\nBukti: status solusi, assignment, langkah, konflik, dan waktu.",
	"Fakta keadaan NPC/player menjadi premis aturan IF–THEN. Forward chaining menambahkan kesimpulan yang terpicu.\nBukti: fakta awal, aturan yang aktif, fakta hasil, ASK/model checking/resolution, dan keputusan NPC.",
	"State planning adalah kumpulan fakta; goal adalah TACTIC_READY. Aksi berisi precondition, add, dan delete effects.\nPlanner forward mencari dari state awal; backward melakukan regresi dari goal.\nBukti: rencana non-kosong, state/goal, heuristik relaxed, serta mutex.",
]
var start_button: Button
var center_container: CenterContainer
var menu_panel: PanelContainer
var material_grid: GridContainer

func _ready() -> void:
	_build_menu()
	get_viewport().size_changed.connect(_update_menu_layout)

func _build_menu() -> void:
	var background := ColorRect.new()
	background.color = Color("101722")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	center_container = CenterContainer.new()
	center_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center_container)
	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", _panel_style(Color("151f2b"), Color("334556")))
	center_container.add_child(menu_panel)
	var margin := _make_margin(menu_panel, 22, 24)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)
	var title := Label.new()
	title.text = "AI DUNGEON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("f1f5f9"))
	title.add_theme_font_size_override("font_size", 32)
	content.add_child(title)
	_add_section_heading(content, "PENERAPAN MATERI", "Metode, cara kerja, dan bukti yang dapat diamati di dalam game")
	material_grid = _create_material_grid(content)

	start_button = _make_action_button("Mulai Pembuktian", true)
	start_button.text = "Mainkan"
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.pressed.connect(_start)
	content.add_child(start_button)
	_update_menu_layout()

func _make_margin(parent: Control, vertical: int, horizontal: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)
	parent.add_child(margin)
	return margin

func _add_section_heading(parent: VBoxContainer, heading: String, subtitle: String) -> void:
	var heading_box := VBoxContainer.new()
	heading_box.add_theme_constant_override("separation", 2)
	parent.add_child(heading_box)
	var title := Label.new()
	title.text = heading
	title.add_theme_color_override("font_color", Color("e7edf3"))
	title.add_theme_font_size_override("font_size", 14)
	heading_box.add_child(title)
	var hint := Label.new()
	hint.text = subtitle
	hint.add_theme_color_override("font_color", Color("8f9eac"))
	hint.add_theme_font_size_override("font_size", 11)
	heading_box.add_child(hint)

func _create_material_grid(parent: VBoxContainer) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "MaterialGrid"
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	for index in range(LESSONS.size()):
		var card := PanelContainer.new()
		card.name = "MaterialCard%d" % (index + 1)
		card.add_theme_stylebox_override("panel", _panel_style(Color("1b2734"), Color("334556")))
		grid.add_child(card)
		var card_margin := _make_margin(card, 10, 12)
		var card_content := VBoxContainer.new()
		card_content.add_theme_constant_override("separation", 5)
		card_margin.add_child(card_content)
		var heading := Label.new()
		heading.text = "%02d  %s" % [index + 1, LESSONS[index][0]]
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		heading.add_theme_color_override("font_color", Color("7ce0d0"))
		heading.add_theme_font_size_override("font_size", 14)
		card_content.add_child(heading)
		var explanation := Label.new()
		explanation.text = DETAILS[index]
		explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		explanation.add_theme_color_override("font_color", Color("c5d0db"))
		explanation.add_theme_font_size_override("font_size", 11)
		card_content.add_child(explanation)
	return grid

func _make_action_button(label: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 44
	if primary:
		button.add_theme_stylebox_override("normal", _panel_style(Color("247c78"), Color("78e2d2")))
		button.add_theme_stylebox_override("hover", _panel_style(Color("2c9990"), Color("a0f0e4")))
		button.add_theme_stylebox_override("pressed", _panel_style(Color("1b605e"), Color("78e2d2")))
	return button

func _panel_style(background: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _update_menu_layout() -> void:
	if not center_container or not menu_panel or not material_grid:
		return
	var layout := _get_menu_layout(get_viewport_rect().size.x)
	var content_width := float(layout.content_width)
	center_container.custom_minimum_size.x = content_width
	menu_panel.custom_minimum_size.x = float(layout.panel_width)
	var columns := int(layout.columns)
	var available_grid_width := float(layout.panel_width) - 56.0
	var card_width := (available_grid_width - float(columns - 1) * 8.0) / float(columns)
	material_grid.columns = columns
	for card in material_grid.get_children():
		if card is Control:
			card.custom_minimum_size.x = card_width
	if start_button:
		start_button.custom_minimum_size.x = available_grid_width

func _get_menu_layout(viewport_width: float) -> Dictionary:
	var content_width := minf(820.0, maxf(240.0, viewport_width - 24.0))
	return {
		"content_width": content_width,
		"panel_width": maxf(216.0, content_width - 24.0),
		"columns": 2 if content_width >= 650.0 else 1
	}

func _start() -> void:
	get_tree().set_meta("selected_ai_stage", _get_start_stage())
	get_tree().change_scene_to_file(GAME_SCENE)

func _get_start_stage() -> int:
	return 0
