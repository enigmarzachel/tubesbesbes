class_name LogicInferenceOverlay
extends CanvasLayer

var summary_label: Label
var detail_label: Label
var detail_scroll: ScrollContainer
var detail_button: Button
var panel: PanelContainer
var has_inference := false
var has_successful_plan := false

const COLOR_BG := Color(0.055, 0.075, 0.10, 0.94)
const COLOR_ACCENT := Color(0.25, 0.78, 0.72)

func _ready() -> void:
	add_to_group("logic_inference_overlay")
	panel = PanelContainer.new()
	panel.name = "KnowledgeBasePanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 10.0
	panel.offset_top = -130.0
	panel.offset_right = 320.0
	panel.offset_bottom = -10.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_color = COLOR_ACCENT
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	summary_label = Label.new()
	summary_label.text = "NPC reasoning\nMenunggu fakta..."
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", 12)
	box.add_child(summary_label)
	detail_button = Button.new()
	detail_button.text = "Tampilkan detail ▾"
	detail_button.custom_minimum_size.y = 26
	detail_button.pressed.connect(_toggle_details)
	box.add_child(detail_button)
	detail_scroll = ScrollContainer.new()
	detail_scroll.custom_minimum_size = Vector2(270.0, 0.0)
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.visible = false
	box.add_child(detail_scroll)
	detail_label = Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 10)
	detail_label.custom_minimum_size.x = 260.0
	detail_scroll.add_child(detail_label)

func _toggle_details() -> void:
	detail_scroll.visible = not detail_scroll.visible
	detail_button.text = "Sembunyikan detail ▴" if detail_scroll.visible else "Tampilkan detail ▾"
	panel.offset_top = -310.0 if detail_scroll.visible else -130.0

func show_inference(npc_name: String, decision: String, result: Dictionary) -> void:
	if not summary_label:
		return
	has_inference = true
	var facts: Dictionary = result.get("facts", {})
	var initial: Array = result.get("initial_facts", [])
	var trace: Array = result.get("trace", [])
	var rules := PropositionalKnowledgeBase.get_rules()
	var typed_initial: Array[String] = []
	for fact in initial:
		typed_initial.append(String(fact))
	var model_result := PropositionalInferenceEngine.model_check(typed_initial, rules, "COORDINATED_ASSAULT")
	var resolution_result := PropositionalInferenceEngine.resolution_entails(typed_initial, rules, "COORDINATED_ASSAULT")
	var initial_text := ""
	for index in range(initial.size()):
		if index > 0:
			initial_text += ", "
		initial_text += String(initial[index])
	var detail_lines: Array[String] = ["Fakta: %s" % (initial_text if not initial_text.is_empty() else "(kosong)")]
	if trace.is_empty():
		detail_lines.append("Forward chaining: tidak ada aturan aktif")
	else:
		for step in trace:
			var rule_name := String(step.get("rule", "rule"))
			detail_lines.append("FC %s → %s" % [rule_name.substr(0, 2), step.get("fact", "")])
	detail_lines.append("ASK coordinated: %s" % ("ya" if facts.has("COORDINATED_ASSAULT") else "belum"))
	detail_lines.append("Model checking: %s (%d dunia)" % ["entail" if model_result.get("entailed", false) else "belum entail", int(model_result.get("models_checked", 0))])
	detail_lines.append("Resolution: %s (%d clause)" % ["terbukti" if resolution_result.get("entailed", false) else "belum terbukti", int(resolution_result.get("clauses", 0))])
	var planning: Dictionary = result.get("planning", {})
	var forward_plan: Dictionary = planning.get("forward", {})
	has_successful_plan = bool(forward_plan.get("success", false)) and not forward_plan.get("plan", []).is_empty()
	if not planning.is_empty():
		var forward: Dictionary = planning.get("forward", {})
		var backward: Dictionary = planning.get("backward", {})
		var h: Dictionary = planning.get("heuristic", {})
		var graph: Dictionary = planning.get("graph", {})
		detail_lines.append("Plan maju: %s" % str(forward.get("plan", [])))
		detail_lines.append("Regresi: %s" % str(backward.get("plan", [])))
		detail_lines.append("h_relax=%d | mutex aksi/fakta=%d/%d" % [int(h.get("value", -1)), graph.get("action_mutex", {}).size(), graph.get("fact_mutex", {}).size()])
	summary_label.text = "NPC reasoning • %s\nFakta: %s\nKeputusan: %s\nPlan: %s" % [npc_name, initial_text if not initial_text.is_empty() else "tidak ada fakta", decision, str(result.get("planning", {}).get("forward", {}).get("plan", []))]
	detail_label.text = "\n".join(detail_lines)
