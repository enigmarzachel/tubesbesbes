extends Area2D

@export var tilemap_layer: TileMapLayer
@export var grid_manager: GridManager
@export var duri_cost: float = 10.0

func _ready() -> void:
	if tilemap_layer and grid_manager:
		grid_manager.register_duri(tilemap_layer.local_to_map(global_position), duri_cost)
