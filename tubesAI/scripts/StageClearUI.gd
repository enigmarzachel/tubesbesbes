class_name StageClearUI
extends CanvasLayer

signal restart_pressed
signal explore_pressed

@onready var backdrop: ColorRect = $Backdrop
@onready var modal: Control = $CenterContainer/PanelModal
@onready var lbl_title: Label = $CenterContainer/PanelModal/MarginContainer/VBoxContainer/LblTitle
@onready var lbl_subtitle: Label = $CenterContainer/PanelModal/MarginContainer/VBoxContainer/LblSubtitle
@onready var lbl_stats: Label = $CenterContainer/PanelModal/MarginContainer/VBoxContainer/PanelStats/Margin/LblStats
@onready var btn_restart: Button = $CenterContainer/PanelModal/MarginContainer/VBoxContainer/HBoxButtons/BtnRestart
@onready var btn_explore: Button = $CenterContainer/PanelModal/MarginContainer/VBoxContainer/HBoxButtons/BtnExplore

var is_showing: bool = false

func _ready() -> void:
	add_to_group("stage_clear_ui")
	visible = false
	if btn_restart:
		btn_restart.pressed.connect(_on_restart_pressed)
	if btn_explore:
		btn_explore.pressed.connect(_on_explore_pressed)

func show_clear_screen(total_enemies: int = 5) -> void:
	if is_showing: return
	is_showing = true
	visible = true

	# Disable player movement saat popup aktif
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().root.find_child("player", true, false)
	if player and player.has_method("set_physics_process"):
		player.set_physics_process(false)

	if lbl_stats:
		lbl_stats.text = "⚔️ Goblin Tereliminasi: %d / %d\n✨ Dungeon Berhasil Dibersihkan!" % [total_enemies, total_enemies]

	# Animasi Entrance Modal
	if backdrop:
		backdrop.modulate.a = 0.0
		var t_bg = create_tween()
		t_bg.tween_property(backdrop, "modulate:a", 1.0, 0.4)

	if modal:
		modal.scale = Vector2(0.7, 0.7)
		modal.modulate.a = 0.0
		modal.pivot_offset = modal.size / 2.0
		var t_modal = create_tween().set_parallel(true)
		t_modal.tween_property(modal, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t_modal.tween_property(modal, "modulate:a", 1.0, 0.35)

func _on_restart_pressed() -> void:
	emit_signal("restart_pressed")
	get_tree().reload_current_scene()

func _on_explore_pressed() -> void:
	emit_signal("explore_pressed")
	# Re-enable player movement
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().root.find_child("player", true, false)
	if player and player.has_method("set_physics_process"):
		player.set_physics_process(true)

	# Animasi Fade Out
	var t = create_tween().set_parallel(true)
	if backdrop: t.tween_property(backdrop, "modulate:a", 0.0, 0.3)
	if modal:
		t.tween_property(modal, "scale", Vector2(0.8, 0.8), 0.3).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(modal, "modulate:a", 0.0, 0.25)
	await t.finished
	visible = false
	is_showing = false
