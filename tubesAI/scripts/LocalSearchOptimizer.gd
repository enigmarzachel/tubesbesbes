class_name LocalSearchOptimizer
extends RefCounted

## Modul optimasi konfigurasi NPC menggunakan Simulated Annealing dan Hill Climbing (Tubes Tahap 3).
## Menghasilkan variasi susunan NPC dan item untuk mencapai fitness tertinggi terhadap Player.

# Parameter default Simulated Annealing
var initial_temp: float = 100.0
var cooling_rate: float = 0.995
var min_temp: float = 0.01

# Batasan ruang pencarian konfigurasi NPC
var min_npc_count: int = 1
var max_npc_count: int = 4
var max_items_per_npc: int = 3

func _init(p_temp: float = 100.0, p_cooling: float = 0.995, p_min_temp: float = 0.01) -> void:
	initial_temp = maxf(0.01, p_temp)
	cooling_rate = clampf(p_cooling, 0.0001, 0.9999)
	min_temp = maxf(0.0001, p_min_temp)

## Menghasilkan konfigurasi awal NPC secara acak
func create_random_config(npc_count: int = -1) -> Array:
	if npc_count <= 0:
		npc_count = randi_range(min_npc_count, max_npc_count)
	
	var available_types = NPCFitnessEvaluator.get_available_npc_types()
	var available_items = NPCFitnessEvaluator.get_available_items()
	
	var config: Array = []
	for i in range(npc_count):
		var chosen_type: String = available_types[randi() % available_types.size()]
		var item_count: int = randi_range(0, 2)
		var items: Array = []
		for j in range(item_count):
			var it: String = available_items[randi() % available_items.size()]
			if it != "NONE" and not (it in items):
				items.append(it)
		
		config.append({
			"type": chosen_type,
			"items": items
		})
	return config

## Membuat salinan mendalam (deep copy) konfigurasi NPC
func duplicate_config(config: Array) -> Array:
	var copy: Array = []
	for npc in config:
		if npc is Dictionary:
			var npc_copy: Dictionary = npc.duplicate(true)
			if npc_copy.has("items") and (npc_copy["items"] is Array):
				npc_copy["items"] = npc_copy["items"].duplicate()
			copy.append(npc_copy)
	return copy

## Menghasilkan variasi acak tetangga (neighbor) dari konfigurasi saat ini
func get_neighbor(config: Array) -> Array:
	var neighbor: Array = duplicate_config(config)
	if neighbor.is_empty():
		return create_random_config(1)
	
	var available_types = NPCFitnessEvaluator.get_available_npc_types()
	var available_items = NPCFitnessEvaluator.get_available_items()
	
	var mutation_type: int = randi() % 4
	match mutation_type:
		0:
			if neighbor.size() < max_npc_count:
				var new_type: String = available_types[randi() % available_types.size()]
				neighbor.append({
					"type": new_type,
					"items": []
				})
			else:
				var idx = randi() % neighbor.size()
				neighbor[idx]["type"] = available_types[randi() % available_types.size()]
		1:
			if neighbor.size() > min_npc_count:
				var idx = randi() % neighbor.size()
				neighbor.remove_at(idx)
			else:
				_mutate_npc_items(neighbor[0], available_items)
		2:
			var idx = randi() % neighbor.size()
			_mutate_npc_items(neighbor[idx], available_items)
		3:
			var idx = randi() % neighbor.size()
			var current_type: String = neighbor[idx].get("type", "Orc")
			var candidate_types = []
			for t in available_types:
				if t != current_type:
					candidate_types.append(t)
			if not candidate_types.is_empty():
				neighbor[idx]["type"] = candidate_types[randi() % candidate_types.size()]
	
	return neighbor

## Memodifikasi daftar item pada objek NPC
func _mutate_npc_items(npc: Dictionary, available_items: Array) -> void:
	if not npc.has("items") or not (npc["items"] is Array):
		npc["items"] = []
	
	var items: Array = npc["items"]
	var action: int = randi() % 3
	
	if action == 0 and items.size() < max_items_per_npc:
		var new_item: String = available_items[randi() % available_items.size()]
		if new_item != "NONE" and not (new_item in items):
			items.append(new_item)
	elif action == 1 and not items.is_empty():
		var remove_idx = randi() % items.size()
		items.remove_at(remove_idx)
	elif not items.is_empty():
		var replace_idx = randi() % items.size()
		var candidate_items = []
		for it in available_items:
			if it != "NONE" and not (it in items):
				candidate_items.append(it)
		if not candidate_items.is_empty():
			items[replace_idx] = candidate_items[randi() % candidate_items.size()]
		else:
			items.remove_at(replace_idx)
	else:
		var new_item: String = available_items[randi() % available_items.size()]
		if new_item != "NONE":
			items.append(new_item)

## Optimasi konfigurasi NPC dengan algoritma Simulated Annealing
func optimize_simulated_annealing(player_stats: Dictionary, initial_config: Array = []) -> Dictionary:
	var current_config: Array
	if initial_config.is_empty():
		current_config = create_random_config()
	else:
		current_config = duplicate_config(initial_config)
	
	var current_fitness: float = NPCFitnessEvaluator.evaluate_fitness(current_config, player_stats)
	var best_config: Array = duplicate_config(current_config)
	var best_fitness: float = current_fitness
	var initial_fitness: float = current_fitness
	
	var current_temp: float = initial_temp
	var effective_cooling: float = clampf(cooling_rate, 0.0001, 0.9999)
	var iterations: int = 0
	var accepted_worse_moves: int = 0
	const MAX_SAFETY_ITERATIONS: int = 50000
	
	while current_temp > min_temp and iterations < MAX_SAFETY_ITERATIONS:
		iterations += 1
		
		var neighbor: Array = get_neighbor(current_config)
		var neighbor_fitness: float = NPCFitnessEvaluator.evaluate_fitness(neighbor, player_stats)
		
		var delta_E: float = neighbor_fitness - current_fitness
		var accept: bool = false
		
		if delta_E > 0.0:
			accept = true
		else:
			if current_temp > 0.0:
				var exponent: float = clampf(delta_E / current_temp, -50.0, 0.0)
				var acceptance_prob: float = exp(exponent)
				if randf() < acceptance_prob:
					accept = true
					accepted_worse_moves += 1
		
		if accept:
			current_config = neighbor
			current_fitness = neighbor_fitness
			
			if current_fitness > best_fitness:
				best_fitness = current_fitness
				best_config = duplicate_config(current_config)
		
		current_temp *= effective_cooling
	
	return {
		"algorithm": "Simulated Annealing",
		"best_config": best_config,
		"best_fitness": best_fitness,
		"initial_fitness": initial_fitness,
		"iterations": iterations,
		"accepted_worse_moves": accepted_worse_moves,
		"final_temp": current_temp,
		"player_power": NPCFitnessEvaluator.calculate_player_power(player_stats),
		"npc_total_power": NPCFitnessEvaluator.calculate_npc_total_power(best_config)["total_power"]
	}

## Optimasi konfigurasi NPC dengan algoritma Hill Climbing
func optimize_hill_climbing(player_stats: Dictionary, initial_config: Array = [], max_iterations: int = 500) -> Dictionary:
	var current_config: Array
	if initial_config.is_empty():
		current_config = create_random_config()
	else:
		current_config = duplicate_config(initial_config)
	
	var current_fitness: float = NPCFitnessEvaluator.evaluate_fitness(current_config, player_stats)
	var best_config: Array = duplicate_config(current_config)
	var best_fitness: float = current_fitness
	var initial_fitness: float = current_fitness
	
	var iterations: int = 0
	var improvements: int = 0
	var safe_max_iter: int = maxi(1, max_iterations)
	
	for i in range(safe_max_iter):
		iterations += 1
		var neighbor: Array = get_neighbor(current_config)
		var neighbor_fitness: float = NPCFitnessEvaluator.evaluate_fitness(neighbor, player_stats)
		
		if neighbor_fitness > current_fitness:
			current_config = neighbor
			current_fitness = neighbor_fitness
			improvements += 1
			
			if current_fitness > best_fitness:
				best_fitness = current_fitness
				best_config = duplicate_config(current_config)
	
	return {
		"algorithm": "Hill Climbing",
		"best_config": best_config,
		"best_fitness": best_fitness,
		"initial_fitness": initial_fitness,
		"iterations": iterations,
		"improvements": improvements,
		"player_power": NPCFitnessEvaluator.calculate_player_power(player_stats),
		"npc_total_power": NPCFitnessEvaluator.calculate_npc_total_power(best_config)["total_power"]
	}
