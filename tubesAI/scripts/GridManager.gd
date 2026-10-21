extends Node2D
class_name GridManager

@onready var lantai: TileMapLayer = $lantai
@onready var wall_bottom: TileMapLayer = $wallBotom
@onready var vertical_top: TileMapLayer = $verticalTop

var duri_cells: Dictionary = {}

func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var next = cell + dir
		if is_passable(next):
			neighbors.append(next)
	return neighbors

func is_passable(cell: Vector2i) -> bool:
	var has_wall_bot = wall_bottom.get_cell_tile_data(cell) if wall_bottom else null
	var has_wall_top = vertical_top.get_cell_tile_data(cell) if vertical_top else null
	if has_wall_bot != null or has_wall_top != null:
		return false
	return (lantai.get_cell_tile_data(cell) if lantai else null) != null

func register_duri(grid_pos: Vector2i, cost: float = 10.0) -> void:
	duri_cells[grid_pos] = cost

func unregister_duri(grid_pos: Vector2i) -> void:
	duri_cells.erase(grid_pos)

func get_step_cost(cell: Vector2i) -> float:
	return duri_cells[cell] if duri_cells.has(cell) else 1.0


# Helper integrasi Local Search & Spawning NPC (Tubes Tahap 3)
func spawn_optimized_npcs(player_stats_override: Dictionary = {}, use_simulated_annealing: bool = true) -> Array:
	var player_node: Node2D = get_tree().get_first_node_in_group("player") if get_tree() else null
	var active_lantai: TileMapLayer = lantai if lantai else get_node_or_null("lantai")
	
	var player_stats: Dictionary = {
		"hp": 100,
		"attack": 20,
		"defense": 5,
		"potion": 2
	}
	if not player_stats_override.is_empty():
		for k in player_stats_override:
			player_stats[k] = player_stats_override[k]
	elif player_node and "hp" in player_node:
		player_stats["hp"] = player_node.hp
	
	var optimizer = LocalSearchOptimizer.new()
	var opt_result: Dictionary = optimizer.optimize_simulated_annealing(player_stats) if use_simulated_annealing else optimizer.optimize_hill_climbing(player_stats)
	var best_config: Array = opt_result.get("best_config", [])
	
	var spawned_enemies: Array = []
	var enemy_scene = load("res://scenes/enemy.tscn")
	if not enemy_scene:
		push_warning("Tidak dapat memuat scene res://scenes/enemy.tscn untuk spawning NPC.")
		return spawned_enemies
	
	var entities_parent: Node = get_node_or_null("entities")
	if not entities_parent:
		entities_parent = self
	
	var battle_mgr = get_tree().get_first_node_in_group("battle_manager") if get_tree() else null
	var debug_node = get_node_or_null("PathfindingDebug")
	
	var passable_cells: Array[Vector2i] = []
	if active_lantai:
		for cell in active_lantai.get_used_cells():
			if is_passable(cell) and not duri_cells.has(cell):
				passable_cells.append(cell)
	passable_cells.shuffle()
	
	for i in range(best_config.size()):
		var npc_data: Dictionary = best_config[i]
		var enemy_instance = enemy_scene.instantiate() as CharacterBody2D
		if not enemy_instance:
			continue
		
		# Tentukan posisi spawn sebelum add_child agar home_grid_pos valid di _ready
		var spawn_pos: Vector2
		if i < passable_cells.size() and active_lantai:
			spawn_pos = active_lantai.map_to_local(passable_cells[i])
		else:
			spawn_pos = Vector2(-200.0 + (i * 35.0), 0.0)
		
		enemy_instance.global_position = spawn_pos
		enemy_instance.set("tilemap_layer", active_lantai)
		enemy_instance.set("grid_manager", self)
		enemy_instance.set("player", player_node)
		enemy_instance.set("debug_node", debug_node)
		enemy_instance.set("battle_manager", battle_mgr)
		enemy_instance.set_meta("npc_config", npc_data)
		enemy_instance.name = "NPC_%s_%d" % [npc_data.get("type", "Enemy"), i + 1]
		
		entities_parent.add_child(enemy_instance)
		spawned_enemies.append(enemy_instance)
	
	return spawned_enemies


# Helper integrasi Constraint Satisfaction Problem (CSP) (Tubes Tahap 4)
func spawn_csp_enemies(options: Dictionary = {}) -> Array:
	var solver = CSPSolver.new()
	var battle_mgr = get_tree().get_first_node_in_group("battle_manager") if get_tree() else null
	var placement = solver.solve_arena_placement(self, options)
	return solver.spawn_enemies_from_csp(self, battle_mgr, placement)
