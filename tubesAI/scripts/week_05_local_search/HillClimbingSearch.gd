class_name HillClimbingSearch
extends RefCounted

## Steepest-ascent hill climbing: evaluate all one-edit neighbors, then take the best improving one.
static func search(optimizer, player_stats: Dictionary, initial_config: Array = [], max_iterations: int = 500) -> Dictionary:
	var current: Array = optimizer.create_random_config() if initial_config.is_empty() else optimizer.duplicate_config(initial_config)
	var current_fitness: float = NPCFitnessEvaluator.evaluate_fitness(current, player_stats)
	var initial_fitness := current_fitness
	var iterations := 0
	var improvements := 0
	var safe_limit := maxi(0, max_iterations)

	while iterations < safe_limit and current_fitness < 100.0:
		var neighbors: Array = optimizer.get_all_neighbors(current)
		if neighbors.is_empty():
			break
		var best_neighbor: Array = current
		var best_neighbor_fitness := current_fitness
		for candidate in neighbors:
			var candidate_fitness: float = NPCFitnessEvaluator.evaluate_fitness(candidate, player_stats)
			if candidate_fitness > best_neighbor_fitness:
				best_neighbor = candidate
				best_neighbor_fitness = candidate_fitness
		iterations += 1
		if best_neighbor_fitness <= current_fitness:
			break
		current = optimizer.duplicate_config(best_neighbor)
		current_fitness = best_neighbor_fitness
		improvements += 1

	return {
		"algorithm": "Steepest-Ascent Hill Climbing",
		"best_config": current,
		"best_fitness": current_fitness,
		"initial_fitness": initial_fitness,
		"iterations": iterations,
		"improvements": improvements,
		"player_power": NPCFitnessEvaluator.calculate_player_power(player_stats),
		"npc_total_power": NPCFitnessEvaluator.calculate_npc_total_power(current)["total_power"]
	}
