# PathfindingDebug.gd
extends Node2D

@export var tilemap_layer: TileMapLayer
@export var show_debug: bool = true

# Durasi animasi ekspansi (detik). Disetting 0.36 agar pas dengan cooldown pergerakan enemy
@export var anim_duration: float = 0.36 

# Warna overlay
@export var color_expanded: Color = Color(0.8, 0.2, 0.2, 0.35)  # Merah (Node yang dievaluasi)
@export var color_path: Color = Color(0.1, 0.9, 0.2, 0.6)      # Hijau (Jalur Akhir)
@export var color_path_line: Color = Color(0.0, 1.0, 0.5, 0.9) # Garis penunjuk rute

var expansion_order: Array = []
var final_path: Array = []
var current_step_count: int = 0
var show_final_path: bool = false
var active_tween: Tween

func update_debug_data(result: Dictionary) -> void:
	if not show_debug or result.is_empty():
		_clear_debug()
		return

	# Hentikan animasi sebelumnya jika musuh menghitung ulang saat animasi masih jalan
	if active_tween and active_tween.is_running():
		active_tween.kill()

	expansion_order = result.get("expansion_order", [])
	final_path = result.get("path", [])
	current_step_count = 0
	show_final_path = false
	
	if expansion_order.is_empty():
		show_final_path = true
		queue_redraw()
		return

	# Buat Tween untuk meng-animasikan jumlah petak terbuka dari 0 ke total petak yang di-expand
	active_tween = create_tween()
	active_tween.tween_method(
		_on_step_updated,
		0,
		expansion_order.size(),
		anim_duration
	)
	
	# CALLBACK: Saat ekspansi gelombang selesai, baru jalur hijau dimunculkan
	active_tween.finished.connect(func():
		show_final_path = true
		queue_redraw()
	)

func _on_step_updated(step: int) -> void:
	current_step_count = step
	queue_redraw()

func _clear_debug() -> void:
	expansion_order.clear()
	final_path.clear()
	current_step_count = 0
	show_final_path = false
	queue_redraw()

func _draw() -> void:
	if not show_debug or not tilemap_layer:
		return

	var tile_size = Vector2(tilemap_layer.tile_set.tile_size)

	# 1. Gambar petak ekspansi secara bertahap (satu per satu sesuai progress animasi)
	for i in range(min(current_step_count, expansion_order.size())):
		var cell = expansion_order[i]
		_draw_cell_rect(cell, tile_size, color_expanded)

	# 2. HANYA gambar jalur akhir jika animasi ekspansi sudah selesai sampai ke Player
	if show_final_path and not final_path.is_empty():
		for cell in final_path:
			_draw_cell_rect(cell, tile_size, color_path)

		var line_points: PackedVector2Array = []
		for cell in final_path:
			line_points.append(tilemap_layer.map_to_local(cell))

		if line_points.size() > 1:
			draw_polyline(line_points, color_path_line, 3.0)

func _draw_cell_rect(cell: Vector2i, tile_size: Vector2, color: Color) -> void:
	var center_pixel = tilemap_layer.map_to_local(cell)
	var top_left = center_pixel - (tile_size / 2.0)
	var rect = Rect2(top_left, tile_size)
	draw_rect(rect, color, true)
