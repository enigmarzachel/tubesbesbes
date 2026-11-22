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
			if not npc_copy.has("type"):
				npc_copy["type"] = "Orc"
			if not npc_copy.has("items") or not (npc_copy["items"] is Array):
				npc_copy["items"] = []
			else:
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

## Menghasilkan seluruh konfigurasi yang berbeda dengan satu edit dari state saat ini.
## Dipakai steepest-ascent Hill Climbing, sedangkan SA mengambil satu tetangga acak.
func get_all_neighbors(config: Array) -> Array:
	var neighbors: Array = []
	var available_types = NPCFitnessEvaluator.get_available_npc_types()
	var available_items = NPCFitnessEvaluator.get_available_items()
	if config.is_empty():
		return [create_random_config(1)]

	if config.size() > min_npc_count:
		var reduced := duplicate_config(config)
		for index in range(reduced.size()):
			var candidate := duplicate_config(reduced)
			candidate.remove_at(index)
			if not neighbors.has(candidate): neighbors.append(candidate)

	if config.size() < max_npc_count:
		for npc_type in available_types:
			var candidate := duplicate_config(config)
			candidate.append({"type": String(npc_type), "items": []})
			if not neighbors.has(candidate): neighbors.append(candidate)

	for index in range(config.size()):
		var npc: Dictionary = config[index]
		var old_type := String(npc.get("type", "Orc"))
		for npc_type in available_types:
			if String(npc_type) == old_type: continue
			var candidate := duplicate_config(config)
			candidate[index]["type"] = String(npc_type)
			if not neighbors.has(candidate): neighbors.append(candidate)

		var items: Array = npc.get("items", []).duplicate()
		for item_index in range(items.size()):
			var candidate := duplicate_config(config)
			candidate[index]["items"].remove_at(item_index)
			if not neighbors.has(candidate): neighbors.append(candidate)

		if items.size() < max_items_per_npc:
			for item_name in available_items:
				var key := String(item_name)
				if key == "NONE" or key in items: continue
				var candidate := duplicate_config(config)
				candidate[index]["items"].append(key)
				if not neighbors.has(candidate): neighbors.append(candidate)
		for item_index in range(items.size()):
			for item_name in available_items:
				var key := String(item_name)
				if key == "NONE" or key in items: continue
				var candidate := duplicate_config(config)
				candidate[index]["items"][item_index] = key
				if not neighbors.has(candidate): neighbors.append(candidate)
	return neighbors

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

## Optimasi konfigurasi NPC dengan Simulated Annealing (implementasi di file khusus).
func optimize_simulated_annealing(player_stats: Dictionary, initial_config: Array = []) -> Dictionary:
	return SimulatedAnnealingSearch.search(self, player_stats, initial_config)

## Steepest-ascent Hill Climbing; berhenti pada local optimum atau batas iterasi.
func optimize_hill_climbing(player_stats: Dictionary, initial_config: Array = [], max_iterations: int = 500) -> Dictionary:
	return HillClimbingSearch.search(self, player_stats, initial_config, max_iterations)
