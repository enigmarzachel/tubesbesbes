class_name GreedyBestFirstSearch
extends RefCounted

static func search(grid, start: Vector2i, goal: Vector2i, heuristic_type: String = "manhattan") -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var expanded: Array[Vector2i] = []
	if not grid or not grid.has_method("is_passable") or not grid.is_passable(start) or not grid.is_passable(goal):
		return SearchSupport.make_result(false, [], expanded, [], null, t0)

	var frontier := SearchSupport.PriorityQueue.new()
	var costs := {start: 0.0}
	var parent: Dictionary = {}
	var closed: Dictionary = {}
	var start_h := Pathfinding.heuristic(heuristic_type, start, goal)
	frontier.enqueue(start, start_h)
	while not frontier.is_empty():
		var current := frontier.dequeue()
		if closed.has(current):
			continue
		closed[current] = true
		expanded.append(current)
		if current == goal:
			var path := SearchSupport.reconstruct_path(parent, start, goal)
			return SearchSupport.make_result(true, path, expanded, frontier.cells(), costs[current], t0)
		for next_cell in grid.get_neighbors(current):
			if closed.has(next_cell):
				continue
			var next_cost: float = costs[current] + float(grid.get_step_cost(next_cell))
			if next_cost < float(costs.get(next_cell, INF)):
				costs[next_cell] = next_cost
				parent[next_cell] = current
				frontier.enqueue(next_cell, Pathfinding.heuristic(heuristic_type, next_cell, goal))
	return SearchSupport.make_result(false, [], expanded, frontier.cells(), null, t0)
