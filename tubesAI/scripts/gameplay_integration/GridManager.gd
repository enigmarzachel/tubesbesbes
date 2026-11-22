extends Node2D
class_name GridManager

@onready var lantai: TileMapLayer = $lantai
@onready var wall_bottom: TileMapLayer = $wallBotom
@onready var vertical_top: TileMapLayer = $verticalTop

var duri_cells: Dictionary = {}
var last_csp_result: Dictionary = {}
var last_optimization_result: Dictionary = {}
var last_spawn_error: String = ""

func _ready() -> void:
	add_to_group("grid_manager")

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
func spawn_optimized_npcs(player_stats_override: Dictionary = {}, use_simulated_annealing: bool = true, initial_config: Array = []) -> Array:
	last_spawn_error = ""
	var player_node: Node2D = get_tree().get_first_node_in_group("player") if get_tree() else null
	if not player_node:
		last_spawn_error = "Spawn Local Search dibatalkan: node player tidak ditemukan."
		return []
	var active_lantai: TileMapLayer = lantai if lantai else get_node_or_null("lantai")
	if not active_lantai:
		last_spawn_error = "Arena belum siap: TileMap lantai tidak ditemukan."
		return []
	
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
	var opt_result: Dictionary = optimizer.optimize_simulated_annealing(player_stats, initial_config) if use_simulated_annealing else optimizer.optimize_hill_climbing(player_stats, initial_config, 500)
	last_optimization_result = opt_result
	var best_config: Array = opt_result.get("best_config", [])
	
	var spawned_enemies: Array = []
	var enemy_scene = load("res://scenes/enemy.tscn")
	var enemy_script = load("res://scripts/week_02_agents/enemy.gd")
	if not enemy_scene:
		last_spawn_error = "NPC tidak dapat dibuat karena scene enemy tidak tersedia."
		return spawned_enemies
	if not enemy_script:
		last_spawn_error = "NPC tidak dapat dibuat karena script AI enemy tidak tersedia."
		return spawned_enemies
	
	var entities_parent: Node = get_node_or_null("entities")
	if not entities_parent:
		entities_parent = self
	
	var battle_mgr = get_tree().get_first_node_in_group("battle_manager") if get_tree() else null
	var debug_node = get_node_or_null("PathfindingDebug")
	
	var passable_cells: Array[Vector2i] = []
	var player_cell = active_lantai.local_to_map(active_lantai.to_local(player_node.global_position)) if active_lantai and player_node else Vector2i(-9999, -9999)
	var reachable_cells: Dictionary = {}
	if player_node and player_cell != Vector2i(-9999, -9999):
		reachable_cells = _get_reachable_cells(player_cell)
	var occupied_cells: Array[Vector2i] = []
	var current_enemies = get_tree().get_nodes_in_group("enemies") if get_tree() else []
	for enemy in current_enemies:
		if is_instance_valid(enemy):
			occupied_cells.append(active_lantai.local_to_map(active_lantai.to_local(enemy.global_position)))
	for cell in active_lantai.get_used_cells():
		var far_from_player = player_cell == Vector2i(-9999, -9999) or absi(cell.x - player_cell.x) + absi(cell.y - player_cell.y) >= 3
		var far_from_enemies = true
		for occupied in occupied_cells:
			if absi(cell.x - occupied.x) + absi(cell.y - occupied.y) < 2:
				far_from_enemies = false
				break
		var reachable_from_player = not player_node or reachable_cells.has(cell)
		if is_passable(cell) and not duri_cells.has(cell) and far_from_player and far_from_enemies and reachable_from_player:
			passable_cells.append(cell)
	passable_cells.shuffle()
	if player_node and reachable_cells.is_empty():
		last_spawn_error = "Spawn Local Search dibatalkan: posisi player tidak terhubung ke tile lantai yang bisa dilalui."
		return spawned_enemies
	if passable_cells.is_empty():
		last_spawn_error = "Spawn Local Search dibatalkan: tidak ada sel lantai yang terhubung dan memenuhi jarak aman."
		return spawned_enemies
	
	for i in range(best_config.size()):
		var npc_data: Dictionary = best_config[i]
		var enemy_instance = enemy_scene.instantiate() as CharacterBody2D
		if not enemy_instance:
			continue
		# enemy.tscn berisi sprite/collision saja; pasang AI seperti yang dilakukan CSP.
		if enemy_instance.get_script() == null:
			enemy_instance.set_script(enemy_script)
		
		# Tentukan posisi spawn sebelum add_child agar home_grid_pos valid di _ready
		var spawn_pos: Vector2
		if i < passable_cells.size() and active_lantai:
			spawn_pos = active_lantai.map_to_local(passable_cells[i])
		else:
			break
		
		# Position is expressed in the coordinate space of entities_parent before add_child;
		# assigning global_position before parenting can shift the NPC when parents are transformed.
		enemy_instance.position = entities_parent.to_local(active_lantai.to_global(spawn_pos))
		enemy_instance.set("tilemap_layer", active_lantai)
		enemy_instance.set("grid_manager", self)
		enemy_instance.set("player", player_node)
		enemy_instance.set("debug_node", debug_node)
		enemy_instance.set("battle_manager", battle_mgr)
		enemy_instance.set_meta("npc_config", npc_data)
		enemy_instance.name = "NPC_%s_%d" % [npc_data.get("type", "Enemy"), i + 1]
		
		entities_parent.add_child(enemy_instance)
		if not enemy_instance.is_in_group("enemies"):
			last_spawn_error = "NPC dibuat tetapi gagal masuk ke grup AI enemies."
			enemy_instance.queue_free()
			continue
		spawned_enemies.append(enemy_instance)
		occupied_cells.append(passable_cells[i])
	
	return spawned_enemies


## Sel spawn harus berada di komponen lantai yang sama dengan player agar NPC bisa mengejar.
func _get_reachable_cells(start: Vector2i) -> Dictionary:
	var visited: Dictionary = {}
	if not is_passable(start):
		return visited

	var queue: Array[Vector2i] = [start]
	visited[start] = true
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		for neighbor in get_neighbors(current):
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	return visited


# Helper integrasi Constraint Satisfaction Problem (CSP) (Tubes Tahap 4)
func spawn_csp_enemies(options: Dictionary = {}) -> Array:
	var solver = CSPSolver.new()
	var battle_mgr = get_tree().get_first_node_in_group("battle_manager") if get_tree() else null
	last_csp_result = solver.solve_arena_placement(self, options)
	return solver.spawn_enemies_from_csp(self, battle_mgr, last_csp_result)


func clear_spawned_npcs() -> int:
	var removed := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy.name.begins_with("NPC_") or enemy.name.begins_with("CSP_NPC_"):
			enemy.queue_free()
			removed += 1
	return removed
