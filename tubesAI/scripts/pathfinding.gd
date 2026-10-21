class_name Pathfinding
extends RefCounted

static var current_algorithm: String = "astar"
static var current_heuristic: String = "manhattan"

# --- Priority Queue (Min-Heap) ---
class PriorityQueue:
	var items: Array = []
	var counter: int = 0

	func enqueue(item: Vector2i, priority: float, secondary: float = 0.0) -> void:
		items.append({"item": item, "priority": priority, "secondary": secondary, "order": counter})
		counter += 1
		items.sort_custom(_compare)

	func _compare(a: Dictionary, b: Dictionary) -> bool:
		if a["priority"] != b["priority"]: return a["priority"] < b["priority"]
		if a["secondary"] != b["secondary"]: return a["secondary"] < b["secondary"]
		return a["order"] < b["order"]

	func dequeue() -> Vector2i:
		return Vector2i.ZERO if items.is_empty() else items.pop_front()["item"]

	func is_empty() -> bool:
		return items.is_empty()

	func to_array() -> Array:
		var result = []
		for entry in items:
			result.append(entry["item"])
		return result

# --- Heuristik ---

static func manhattan_heuristic(current: Vector2i, goal: Vector2i) -> float:
	return float(abs(current.x - goal.x) + abs(current.y - goal.y))

static func euclidean_heuristic(current: Vector2i, goal: Vector2i) -> float:
	return Vector2(current).distance_to(Vector2(goal))

static func _get_h(type: String, current: Vector2i, goal: Vector2i) -> float:
	match type.to_lower():
		"manhattan": return manhattan_heuristic(current, goal)
		"euclidean": return euclidean_heuristic(current, goal)
		_: return 0.0

# --- Rekonstruksi Jalur ---

static func _reconstruct_path(parent: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current = goal
	while parent.has(current) or current == start:
		path.append(current)
		if current == start: break
		current = parent.get(current, start)
	if path.is_empty() or path.back() != start:
		return []
	path.reverse()
	return path

# --- UCS & A* ---

static func search_path(grid, start: Vector2i, goal: Vector2i, algorithm: String = "ucs", heuristic_type: String = "manhattan") -> Dictionary:
	var start_time = Time.get_ticks_usec()
	var g_score: Dictionary = {}
	var parent: Dictionary = {}
	var closed: Dictionary = {}
	var frontier = PriorityQueue.new()
	var expansion_order: Array = []
	var is_ucs = (algorithm == "ucs")

	g_score[start] = 0.0
	var h0 = _get_h(heuristic_type, start, goal)
	frontier.enqueue(start, 0.0 if is_ucs else h0, 0.0 if is_ucs else h0)
	var expanded_nodes: int = 0

	while not frontier.is_empty():
		var current = frontier.dequeue()
		if closed.has(current): continue

		expanded_nodes += 1
		closed[current] = true
		expansion_order.append(current)

		if current == goal:
			var path = _reconstruct_path(parent, start, goal)
			return {
				"found": true, "path": path,
				"expanded_nodes": expanded_nodes,
				"expansion_order": expansion_order,
				"frontier_nodes": frontier.to_array(),
				"path_cost": g_score.get(current, 0.0),
				"path_length": max(0, path.size() - 1),
				"search_time_ms": (Time.get_ticks_usec() - start_time) / 1000.0
			}

		for next_cell in grid.get_neighbors(current):
			var new_g = g_score[current] + grid.get_step_cost(next_cell)
			if new_g < g_score.get(next_cell, INF):
				g_score[next_cell] = new_g
				parent[next_cell] = current
				var h = _get_h(heuristic_type, next_cell, goal)
				frontier.enqueue(next_cell, new_g if is_ucs else new_g + h, 0.0 if is_ucs else h)

	return {
		"found": false, "path": [],
		"expanded_nodes": expanded_nodes,
		"expansion_order": [], "frontier_nodes": [],
		"path_cost": null, "path_length": 0,
		"search_time_ms": (Time.get_ticks_usec() - start_time) / 1000.0
	}
