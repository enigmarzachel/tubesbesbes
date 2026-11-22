class_name SimulatedAnnealingSearch
extends RefCounted

static func search(optimizer, player_stats: Dictionary, initial_config: Array = []) -> Dictionary:
	var current: Array = optimizer.create_random_config() if initial_config.is_empty() else optimizer.duplicate_config(initial_config)
	var current_fitness: float = NPCFitnessEvaluator.evaluate_fitness(current, player_stats)
	var best: Array = optimizer.duplicate_config(current)
	var best_fitness := current_fitness
	var initial_fitness := current_fitness
	var temperature: float = optimizer.initial_temp
	var iterations := 0
	var accepted_worse := 0
	var cooling := clampf(optimizer.cooling_rate, 0.0001, 0.9999)
	const MAX_ITERATIONS := 50000

	while temperature > optimizer.min_temp and iterations < MAX_ITERATIONS and best_fitness < 100.0:
		iterations += 1
		var candidate: Array = optimizer.get_neighbor(current)
		var candidate_fitness: float = NPCFitnessEvaluator.evaluate_fitness(candidate, player_stats)
		var delta := candidate_fitness - current_fitness
		var accept := delta > 0.0
		if not accept and temperature > 0.0:
			accept = randf() < exp(clampf(delta / temperature, -50.0, 0.0))
			if accept:
				accepted_worse += 1
		if accept:
			current = candidate
			current_fitness = candidate_fitness
			if current_fitness > best_fitness:
				best = optimizer.duplicate_config(current)
				best_fitness = current_fitness
		temperature *= cooling

	return {
		"algorithm": "Simulated Annealing",
		"best_config": best,
		"best_fitness": best_fitness,
		"initial_fitness": initial_fitness,
		"iterations": iterations,
		"accepted_worse_moves": accepted_worse,
		"final_temp": temperature,
		"player_power": NPCFitnessEvaluator.calculate_player_power(player_stats),
		"npc_total_power": NPCFitnessEvaluator.calculate_npc_total_power(best)["total_power"]
	}
