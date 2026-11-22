class_name Pathfinding
extends RefCounted

static var current_algorithm: String = "astar"
static var current_heuristic: String = "manhattan"

static func manhattan_heuristic(current: Vector2i, goal: Vector2i) -> float:
	return float(absi(current.x - goal.x) + absi(current.y - goal.y))

static func euclidean_heuristic(current: Vector2i, goal: Vector2i) -> float:
	return Vector2(current).distance_to(Vector2(goal))

static func heuristic(heuristic_type: String, current: Vector2i, goal: Vector2i) -> float:
	match heuristic_type.to_lower():
		"manhattan":
			return manhattan_heuristic(current, goal)
		"euclidean":
			return euclidean_heuristic(current, goal)
		_:
			return 0.0

static func search_path(
	grid,
	start: Vector2i,
	goal: Vector2i,
	algorithm: String = "ucs",
	heuristic_type: String = "manhattan"
) -> Dictionary:
	match algorithm.to_lower():
		"ucs":
			return UniformCostSearch.search(grid, start, goal)
		"greedy":
			return GreedyBestFirstSearch.search(grid, start, goal, heuristic_type)
		_:
			return AStarSearch.search(grid, start, goal, heuristic_type)
