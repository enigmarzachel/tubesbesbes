# GridManager.gd
extends Node2D
class_name GridManager

@onready var lantai: TileMapLayer = $lantai
@onready var wall_bottom: TileMapLayer = $wallBotom
@onready var vertical_top: TileMapLayer = $verticalTop

func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	for dir in directions:
		var next_cell = cell + dir
		if is_passable(next_cell):
			neighbors.append(next_cell)
			
	return neighbors

func is_passable(cell: Vector2i) -> bool:
	# Memeriksa apakah petak ini dihalangi oleh wallBotom atau wallTop
	var wall_bot_data = wall_bottom.get_cell_tile_data(cell) if wall_bottom else null
	var vertical_top_data = vertical_top.get_cell_tile_data(cell) if vertical_top else null
	
	if wall_bot_data != null or vertical_top_data != null:
		return false # Ada tembok/halangan
		
	# Memeriksa apakah ada tile lantai
	var lantai_data = lantai.get_cell_tile_data(cell) if lantai else null
	return lantai_data != null

#idupin kalo udah ada tile ber cost tinggi
#func get_step_cost(cell: Vector2i) -> float:
	#if lantai:
		#var tile_data = lantai.get_cell_tile_data(cell)
		#if tile_data and tile_data.get_custom_data("is_water"):
			#return 7.0
	#return 1.0

#matiin kalo udah ada tile ber cost tinggi
func get_step_cost(_cell: Vector2i) -> float:
	# Default cost semua petak adalah 1.0
	return 1.0
