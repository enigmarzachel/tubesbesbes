# pathfinding.gd
class_name Pathfinding
extends RefCounted

# Variabel penyimpan pilihan algoritma saat ini
static var current_algorithm: String = "astar"     # "astar" atau "ucs"
static var current_heuristic: String = "manhattan" # "manhattan" atau "euclidean"

# --- Priority Queue (Min-Heap sederhana) ---
class PriorityQueue:
	var items: Array = []
	var counter: int = 0

	func enqueue(item: Vector2i, priority: float, secondary: float = 0.0) -> void:
		items.append({
			"item": item,
			"priority": priority,
			"secondary": secondary,
			"order": counter
		})
		counter += 1
		items.sort_custom(_compare)

	func _compare(a: Dictionary, b: Dictionary) -> bool:
		if a["priority"] != b["priority"]:
			return a["priority"] < b["priority"]
		if a["secondary"] != b["secondary"]:
			return a["secondary"] < b["secondary"]
		return a["order"] < b["order"]

	func dequeue() -> Vector2i:
		if items.is_empty():
			return Vector2i.ZERO
		return items.pop_front()["item"]

	func is_empty() -> bool:
		return items.is_empty()

	func to_array() -> Array:
		var result = []
		for entry in items:
			result.append(entry["item"])
		return result

# --- Fungsi Heuristik ---
static func zero_heuristic(_current: Vector2i, _goal: Vector2i) -> float:
	return 0.0

static func manhattan_heuristic(current: Vector2i, goal: Vector2i) -> float:
	return abs(current.x - goal.x) + abs(current.y - goal.y)

static func euclidean_heuristic(current: Vector2i, goal: Vector2i) -> float:
	return Vector2(current).distance_to(Vector2(goal))

static func _get_heuristic_value(type_name: String, current: Vector2i, goal: Vector2i) -> float:
	match type_name.to_lower():
		"manhattan":
			return manhattan_heuristic(current, goal)
		"euclidean":
			return euclidean_heuristic(current, goal)
		_:
			return zero_heuristic(current, goal)

# --- Rekonstruksi Jalur ---
static func _reconstruct_path(parent: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current = goal

	while parent.has(current) or current == start:
		path.append(current)
		if current == start:
			break
		current = parent.get(current, start)

	if path.is_empty() or path.back() != start:
		return []

	path.reverse()
	return path

# --- Algoritma Utama (UCS & A*) ---
static func search_path(grid, start: Vector2i, goal: Vector2i, algorithm: String = "ucs", heuristic_type: String = "manhattan") -> Dictionary:
	var start_time = Time.get_ticks_usec()
	var elapsed_ms: float = 0.0

	var g_score: Dictionary = {}
	var parent: Dictionary = {}
	var closed: Dictionary = {}
	var frontier = PriorityQueue.new()
	var expansion_order: Array = []

	g_score[start] = 0.0
	var start_h = _get_heuristic_value(heuristic_type, start, goal)
	var start_priority = 0.0 if algorithm == "ucs" else start_h

	frontier.enqueue(start, start_priority, 0.0 if algorithm == "ucs" else start_h)
	var expanded_nodes: int = 0

	while not frontier.is_empty():
		var current = frontier.dequeue()

		if closed.has(current):
			continue

		expanded_nodes += 1
		closed[current] = true
		expansion_order.append(current)

		# Goal Test
		if current == goal:
			var path = _reconstruct_path(parent, start, goal)
			elapsed_ms = (Time.get_ticks_usec() - start_time) / 1000.0
			return {
				"found": true,
				"path": path,
				"expanded_nodes": expanded_nodes,
				"expansion_order": expansion_order,
				"frontier_nodes": frontier.to_array(),
				"path_cost": g_score.get(current, 0.0),
				"path_length": max(0, path.size() - 1),
				"search_time_ms": elapsed_ms
			}

		# Evaluasi Tetangga
		for next_cell in grid.get_neighbors(current):
			var new_g = g_score[current] + grid.get_step_cost(next_cell)

			if new_g < g_score.get(next_cell, INF):
				g_score[next_cell] = new_g
				parent[next_cell] = current

				var h = _get_heuristic_value(heuristic_type, next_cell, goal)
				var priority = new_g if algorithm == "ucs" else new_g + h
				frontier.enqueue(next_cell, priority, 0.0 if algorithm == "ucs" else h)

	elapsed_ms = (Time.get_ticks_usec() - start_time) / 1000.0
	return {
		"found": false,
		"path": [],
		"expanded_nodes": expanded_nodes,
		"expansion_order": [],
		"frontier_nodes": [],
		"path_cost": null,
		"path_length": 0,
		"search_time_ms": elapsed_ms
	}
