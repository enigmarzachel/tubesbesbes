# duri.gd
extends Area2D

@export var tilemap_layer: TileMapLayer
@export var grid_manager: GridManager
@export var duri_cost: float = 10 # ubah sesuai selera

# duri.gd
func _ready() -> void:
	if tilemap_layer and grid_manager:
		var my_grid: Vector2i = tilemap_layer.local_to_map(global_position)
		grid_manager.register_duri(my_grid, duri_cost)
		print("Duri terdaftar di koordinat grid: ", my_grid) # <-- Cek koordinat ini di console
