class_name SearchSupport
extends RefCounted

class PriorityQueue:
	var items: Array[Dictionary] = []
	var next_order: int = 0

	func enqueue(cell: Vector2i, priority: float, tie_break: float = 0.0) -> void:
		items.append({"cell": cell, "priority": priority, "tie_break": tie_break, "order": next_order})
		next_order += 1
		items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a["priority"] != b["priority"]:
				return a["priority"] < b["priority"]
			if a["tie_break"] != b["tie_break"]:
				return a["tie_break"] < b["tie_break"]
			return a["order"] < b["order"]
		)

	func dequeue() -> Vector2i:
		return items.pop_front()["cell"] if not items.is_empty() else Vector2i.ZERO

	func is_empty() -> bool:
		return items.is_empty()

	func cells() -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		for entry in items:
			result.append(entry["cell"])
		return result

static func reconstruct_path(parent: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current := goal
	while current == start or parent.has(current):
		path.append(current)
		if current == start:
			break
		current = parent[current]
	if path.is_empty() or path.back() != start:
		return []
	path.reverse()
	return path

static func make_result(
	found: bool,
	path: Array[Vector2i],
	expanded: Array[Vector2i],
	frontier: Array[Vector2i],
	cost: Variant,
	start_time_usec: int
) -> Dictionary:
	return {
		"found": found,
		"path": path,
		"expanded_nodes": expanded.size(),
		"expansion_order": expanded,
		"frontier_nodes": frontier,
		"path_cost": cost,
		"path_length": maxi(0, path.size() - 1),
		"search_time_ms": float(Time.get_ticks_usec() - start_time_usec) / 1000.0
	}
