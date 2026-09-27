# PathfindingDebug.gd
extends Node2D

@export var tilemap_layer: TileMapLayer
@export var show_debug: bool = true
@export var anim_duration: float = 0.36 # Pas dengan cooldown pergerakan enemy

@export var color_expanded: Color = Color(0.8, 0.2, 0.2, 0.35)
@export var color_path: Color = Color(0.1, 0.9, 0.2, 0.6)
@export var color_path_line: Color = Color(0.0, 1.0, 0.5, 0.9)

# Struktur data per enemy:
# { enemy_node: { "expansion_order": [...], "path": [...], "step_count": int, "show_path": bool, "tween": Tween } }
var enemy_debug_data: Dictionary = {}

func update_enemy_debug(enemy_source: Node2D, result: Dictionary) -> void:
	if not show_debug or result.is_empty():
		remove_enemy_debug(enemy_source)
		return

	# Jika enemy ini sudah punya animasi aktif, matikan tween lamanya
	if enemy_debug_data.has(enemy_source):
		var old_tween: Tween = enemy_debug_data[enemy_source].get("tween")
		if old_tween and old_tween.is_running():
			old_tween.kill()

	var expansion_order: Array = result.get("expansion_order", [])
	var final_path: Array = result.get("path", [])

	# Buat entri data baru untuk enemy ini
	var data: Dictionary = {
		"expansion_order": expansion_order,
		"path": final_path,
		"step_count": 0,
		"show_path": false,
		"tween": null
	}
	
	enemy_debug_data[enemy_source] = data

	if expansion_order.is_empty():
		data["show_path"] = true
		queue_redraw()
		return

	# Buat Tween khusus untuk enemy ini
	var tween = create_tween()
	data["tween"] = tween
	
	tween.tween_method(
		func(step: int):
			if enemy_debug_data.has(enemy_source):
				enemy_debug_data[enemy_source]["step_count"] = step
				queue_redraw(),
		0,
		expansion_order.size(),
		anim_duration
	)

	# CALLBACK: Saat ekspansi selesai, baru munculkan rute hijau
	tween.finished.connect(func():
		if enemy_debug_data.has(enemy_source):
			enemy_debug_data[enemy_source]["show_path"] = true
			queue_redraw()
	)

func remove_enemy_debug(enemy_source: Node2D) -> void:
	if enemy_debug_data.has(enemy_source):
		var old_tween: Tween = enemy_debug_data[enemy_source].get("tween")
		if old_tween and old_tween.is_running():
			old_tween.kill()
		enemy_debug_data.erase(enemy_source)
		queue_redraw()

func _draw() -> void:
	if not show_debug or not tilemap_layer or enemy_debug_data.is_empty():
		return

	var tile_size = Vector2(tilemap_layer.tile_set.tile_size)

	# Gambar data debug dari SETIAP enemy yang terdaftar
	for enemy in enemy_debug_data:
		var data = enemy_debug_data[enemy]
		var expansion_order = data["expansion_order"]
		var step_count = data["step_count"]
		var final_path = data["path"]

		# 1. Gambar petak ekspansi bertahap sesuai progress animasi step_count
		for i in range(min(step_count, expansion_order.size())):
			_draw_cell_rect(expansion_order[i], tile_size, color_expanded)

		# 2. Gambar Jalur Akhir HANYA jika animasi ekspansi enemy ini sudah selesai
		if data["show_path"] and not final_path.is_empty():
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
