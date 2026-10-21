class_name CSPSolver
extends RefCounted

## Modul Constraint Satisfaction Problem (CSP) untuk Penempatan Entitas Musuh & Hazard (Tubes Tahap 4).
##
## Komponen Utama CSP:
## 1. Variables (X): Slot/posisi tile (Vector2i) pada GridManager yang dapat ditempati entitas.
## 2. Domain (D): Himpunan tipe entitas ("Skeleton", "Orc", "Goblin", "Knight", "duri", "empty") beserta kombinasi item.
## 3. Constraints (C):
##    - Unary: Aturan kelayakan tile (jarak aman spawn player, tipe permukaan, larangan tipe spesifik).
##    - Binary: Jarak minimal antar-musuh (min_enemy_distance), jarak duri-ke-musuh, AllDifferent lokasi.
##    - Global: Total HP maksimum, Total Damage/Attack maksimum, Batasan kuota min/max musuh di arena.
##
## Algoritma Penyelesaian:
## - Backtracking Search dengan MRV (Minimum Remaining Values), Degree Heuristic, LCV, Forward Checking & AC-3.
## - Min-Conflicts Local Search untuk resolusi konflik dari konfigurasi awal.

# Statistik eksekusi terakhir
var backtrack_steps: int = 0
var pruned_values_count: int = 0
var ac3_revisions_count: int = 0
var execution_time_ms: int = 0

# Struktur Default Domain
const DEFAULT_ENEMY_TYPES: Array[String] = ["Skeleton", "Orc", "Goblin", "Knight"]
const DEFAULT_ITEMS_POOL: Array[String] = ["NONE", "SWORD", "SHIELD", "ARMOR"]


# ==============================================================================
# 1. DEFINISI & PEMBUATAN DOMAIN (D)
# ==============================================================================

## Membuat entri domain untuk entitas tertentu dengan atribut HP, damage, defense, dsb.
static func create_domain_entry(
	p_type: String,
	p_items: Array = [],
	p_cost: float = 0.0,
	custom_hp: float = -1.0,
	custom_dmg: float = -1.0
) -> Dictionary:
	var is_empty_val: bool = (p_type.to_lower() == "empty")
	var is_duri_val: bool = (p_type.to_lower() == "duri")
	var is_enemy_val: bool = (not is_empty_val and not is_duri_val)
	
	var base_hp: float = 0.0
	var base_atk: float = 0.0
	var base_def: float = 0.0
	
	if is_enemy_val:
		if ClassDB.class_exists("NPCFitnessEvaluator") or ResourceLoader.exists("res://scripts/NPCFitnessEvaluator.gd"):
			var evaluator_types = NPCFitnessEvaluator.NPC_TYPES
			if evaluator_types.has(p_type):
				base_hp = float(evaluator_types[p_type].get("base_hp", 80.0))
				base_atk = float(evaluator_types[p_type].get("base_attack", 20.0))
				base_def = float(evaluator_types[p_type].get("base_defense", 3.0))
			else:
				base_hp = 80.0
				base_atk = 20.0
				base_def = 3.0
		else:
			match p_type:
				"Skeleton":
					base_hp = 70.0; base_atk = 26.0; base_def = 2.0
				"Orc":
					base_hp = 100.0; base_atk = 20.0; base_def = 5.0
				"Goblin":
					base_hp = 60.0; base_atk = 16.0; base_def = 1.0
				"Knight":
					base_hp = 130.0; base_atk = 16.0; base_def = 8.0
				_:
					base_hp = 80.0; base_atk = 20.0; base_def = 3.0
	elif is_duri_val:
		base_hp = 0.0
		base_atk = 10.0 # Hazard damage
		base_def = 0.0
		if p_cost <= 0.0:
			p_cost = 10.0
	
	# Tambahkan bonus item jika entitas adalah enemy
	var cleaned_items: Array[String] = []
	if is_enemy_val and not p_items.is_empty():
		for item in p_items:
			var it_str = String(item).strip_edges().to_upper()
			if it_str == "NONE" or it_str.is_empty():
				continue
			cleaned_items.append(it_str)
			if ClassDB.class_exists("NPCFitnessEvaluator") or ResourceLoader.exists("res://scripts/NPCFitnessEvaluator.gd"):
				var catalog = NPCFitnessEvaluator.ITEM_CATALOG
				if catalog.has(it_str):
					base_hp += float(catalog[it_str].get("hp_bonus", 0.0))
					base_atk += float(catalog[it_str].get("attack_bonus", 0.0))
					base_def += float(catalog[it_str].get("defense_bonus", 0.0))
			else:
				match it_str:
					"SWORD": base_atk += 8.0
					"SHIELD": base_hp += 20.0; base_def += 6.0
					"ARMOR": base_hp += 35.0; base_atk -= 2.0; base_def += 8.0
	
	if custom_hp >= 0.0: base_hp = custom_hp
	if custom_dmg >= 0.0: base_atk = custom_dmg
	
	var label_id = p_type
	if not cleaned_items.is_empty():
		label_id += "_" + "_".join(cleaned_items)
	
	return {
		"id": label_id,
		"type": p_type,
		"items": cleaned_items,
		"hp": maxf(0.0, base_hp),
		"damage": maxf(0.0, base_atk),
		"defense": maxf(0.0, base_def),
		"cost": p_cost,
		"is_empty": is_empty_val,
		"is_duri": is_duri_val,
		"is_enemy": is_enemy_val
	}

## Menghasilkan daftar domain standar yang memuat kombinasi tipe musuh, duri, dan empty
static func create_default_domain(
	allowed_types: Array = ["Skeleton", "Orc", "duri", "empty"],
	include_item_variants: bool = true
) -> Array[Dictionary]:
	var domain_list: Array[Dictionary] = []
	
	# Selalu sertakan 'empty' sebagai opsi jika diminta
	if "empty" in allowed_types or "Empty" in allowed_types:
		domain_list.append(create_domain_entry("empty"))
	
	# Opsi hazard duri
	if "duri" in allowed_types or "Duri" in allowed_types:
		domain_list.append(create_domain_entry("duri", [], 10.0))
	
	# Opsi entitas musuh
	for t in allowed_types:
		var type_str = String(t)
		if type_str.to_lower() == "empty" or type_str.to_lower() == "duri":
			continue
		
		# Varian tanpa item
		domain_list.append(create_domain_entry(type_str, []))
		
		# Varian dengan item
		if include_item_variants:
			match type_str:
				"Skeleton":
					domain_list.append(create_domain_entry("Skeleton", ["SWORD"]))
				"Orc":
					domain_list.append(create_domain_entry("Orc", ["SHIELD"]))
				"Knight":
					domain_list.append(create_domain_entry("Knight", ["ARMOR"]))
				"Goblin":
					domain_list.append(create_domain_entry("Goblin", ["SWORD"]))
	
	return domain_list


# ==============================================================================
# 2. SISTEM CONSTRAINTS (C): UNARY, BINARY, GLOBAL
# ==============================================================================

## Memeriksa konsistensi constraint Unary untuk satu variabel slot dan satu nilai assignment
func is_unary_consistent(slot_pos: Vector2i, value: Dictionary, constraints: Dictionary) -> bool:
	if value.get("is_empty", false):
		return true
	
	# 1. Aturan jarak aman dari posisi Player
	var player_pos = constraints.get("player_pos", Vector2i(-9999, -9999))
	if player_pos != Vector2i(-9999, -9999):
		var min_player_dist: int = int(constraints.get("min_player_distance", 3))
		var dist_to_player: int = absi(slot_pos.x - player_pos.x) + absi(slot_pos.y - player_pos.y)
		if dist_to_player < min_player_dist:
			return false
	
	# 2. Aturan slot duri yang sudah terdaftar
	var existing_duri = constraints.get("existing_duri_cells", {})
	if existing_duri.has(slot_pos):
		# Jika tile sudah ada duri, musuh tidak bisa ditaruh di sini
		if value.get("is_enemy", false):
			return false
	
	# 3. Aturan tipe tile terlarang / unary callback custom
	if constraints.has("prohibited_types_per_slot"):
		var prohibited: Dictionary = constraints.get("prohibited_types_per_slot", {})
		if prohibited.has(slot_pos):
			var forbidden_list: Array = prohibited[slot_pos]
			if value.get("type", "") in forbidden_list:
				return false
	
	# 4. Aturan custom unary callback jika disediakan
	if constraints.has("unary_validator") and constraints["unary_validator"] is Callable:
		var custom_valid = constraints["unary_validator"].call(slot_pos, value)
		if not custom_valid:
			return false
	
	return true

## Memeriksa konsistensi constraint Binary antara dua slot variabel (slot_a dan slot_b)
func is_binary_consistent(
	slot_a: Vector2i,
	val_a: Dictionary,
	slot_b: Vector2i,
	val_b: Dictionary,
	constraints: Dictionary
) -> bool:
	# AllDifferent posisi: Slot yang sama tidak boleh memiliki dua entitas non-empty
	if slot_a == slot_b:
		if not val_a.get("is_empty", false) and not val_b.get("is_empty", false):
			return false
	
	# Jika salah satu empty, tidak ada konflik relasional antar entitas
	if val_a.get("is_empty", false) or val_b.get("is_empty", false):
		return true
	
	var dist: int = absi(slot_a.x - slot_b.x) + absi(slot_a.y - slot_b.y)
	
	var is_enemy_a: bool = val_a.get("is_enemy", false)
	var is_enemy_b: bool = val_b.get("is_enemy", false)
	var is_duri_a: bool = val_a.get("is_duri", false)
	var is_duri_b: bool = val_b.get("is_duri", false)
	
	# 1. Binary Constraint: Jarak minimal antar-musuh (min_enemy_distance)
	if is_enemy_a and is_enemy_b:
		var min_enemy_dist: int = int(constraints.get("min_enemy_distance", 4))
		if dist < min_enemy_dist:
			return false
		
		# Pembatasan tipe musuh tangguh agar tidak berkumpul di area yang sama
		var elite_types: Array = ["Knight", "Orc"]
		if val_a.get("type", "") in elite_types and val_b.get("type", "") in elite_types:
			var min_elite_dist: int = int(constraints.get("min_elite_distance", 6))
			if dist < min_elite_dist:
				return false
	
	# 2. Binary Constraint: Jarak duri ke duri lain
	if is_duri_a and is_duri_b:
		var min_duri_dist: int = int(constraints.get("min_duri_distance", 2))
		if dist < min_duri_dist:
			return false
	
	# 3. Binary Constraint: Jarak musuh ke duri (musuh tidak boleh spawn berhimpitan dengan duri)
	if (is_enemy_a and is_duri_b) or (is_duri_a and is_enemy_b):
		var min_enemy_duri_dist: int = int(constraints.get("min_enemy_duri_distance", 2))
		if dist < min_enemy_duri_dist:
			return false
	
	return true

## Memeriksa constraint Global pada seluruh penempatan (atau penempatan parsial)
func is_global_consistent(assignment: Dictionary, constraints: Dictionary, is_partial: bool = false) -> bool:
	var total_hp: float = 0.0
	var total_damage: float = 0.0
	var enemy_count: int = 0
	var duri_count: int = 0
	
	for slot in assignment:
		var val: Dictionary = assignment[slot]
		if val.get("is_empty", false):
			continue
		
		total_hp += float(val.get("hp", 0.0))
		total_damage += float(val.get("damage", 0.0))
		
		if val.get("is_enemy", false):
			enemy_count += 1
		elif val.get("is_duri", false):
			duri_count += 1
	
	# Batasan atas selalu dicek baik pada parsial maupun komplit
	var max_hp: float = float(constraints.get("max_total_hp", 350.0))
	if total_hp > max_hp:
		return false
	
	var max_damage: float = float(constraints.get("max_total_damage", 120.0))
	if total_damage > max_damage:
		return false
	
	var max_enemies: int = int(constraints.get("max_enemies", 4))
	if enemy_count > max_enemies:
		return false
	
	var max_duri: int = int(constraints.get("max_duri", 3))
	if duri_count > max_duri:
		return false
	
	# Batasan bawah hanya dicek saat assignment sudah komplit
	if not is_partial:
		var min_enemies: int = int(constraints.get("min_enemies", 2))
		if enemy_count < min_enemies:
			return false
		
		var min_duri: int = int(constraints.get("min_duri", 0))
		if duri_count < min_duri:
			return false
	
	return true


# ==============================================================================
# 3. HEURISTIK MRV & DEGREE HEURISTIC
# ==============================================================================

## Mendapatkan daftar tetangga variabel yang memiliki constraint relasional dengan target_slot
func get_constrained_neighbors(target_slot: Vector2i, all_slots: Array[Vector2i], constraints: Dictionary) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var max_radius: int = maxi(
		int(constraints.get("min_enemy_distance", 4)),
		int(constraints.get("min_duri_distance", 2))
	)
	
	for other in all_slots:
		if other == target_slot:
			continue
		var dist: int = absi(target_slot.x - other.x) + absi(target_slot.y - other.y)
		if dist <= max_radius:
			neighbors.append(other)
	return neighbors

## Memilih variabel unassigned berikutnya menggunakan MRV (Minimum Remaining Values)
## dengan Degree Heuristic sebagai tie-breaker
func select_unassigned_variable_mrv(
	unassigned_vars: Array[Vector2i],
	current_domains: Dictionary,
	all_vars: Array[Vector2i],
	constraints: Dictionary
) -> Vector2i:
	if unassigned_vars.is_empty():
		return Vector2i.ZERO
	
	var min_remaining: int = 999999
	var candidates: Array[Vector2i] = []
	
	# 1. Evaluasi MRV: Hitung ukuran domain yang tersisa
	for var_pos in unassigned_vars:
		var domain_size: int = current_domains[var_pos].size() if current_domains.has(var_pos) else 0
		if domain_size < min_remaining:
			min_remaining = domain_size
			candidates.clear()
			candidates.append(var_pos)
		elif domain_size == min_remaining:
			candidates.append(var_pos)
	
	if candidates.size() == 1:
		return candidates[0]
	
	# 2. Degree Heuristic (Tie-breaker): Pilih variabel dengan jumlah batasan terbanyak terhadap variabel unassigned lainnya
	var max_degree: int = -1
	var best_var: Vector2i = candidates[0]
	
	for candidate in candidates:
		var degree: int = 0
		var neighbors = get_constrained_neighbors(candidate, all_vars, constraints)
		for neighbor in neighbors:
			if neighbor in unassigned_vars:
				degree += 1
		
		if degree > max_degree:
			max_degree = degree
			best_var = candidate
	
	return best_var

## Least Constraining Value (LCV): Mengurutkan nilai domain agar memangkas pilihan tetangga seminimal mungkin
func order_domain_values_lcv(
	var_pos: Vector2i,
	domain_values: Array,
	unassigned_vars: Array[Vector2i],
	current_domains: Dictionary,
	constraints: Dictionary
) -> Array:
	if domain_values.size() <= 1:
		return domain_values
	
	var neighbors = get_constrained_neighbors(var_pos, unassigned_vars, constraints)
	var value_scores: Array = []
	
	for val in domain_values:
		var ruled_out_count: int = 0
		for neighbor in neighbors:
			if not (neighbor in unassigned_vars):
				continue
			var neighbor_domain: Array = current_domains.get(neighbor, [])
			for n_val in neighbor_domain:
				if not is_binary_consistent(var_pos, val, neighbor, n_val, constraints):
					ruled_out_count += 1
		
		value_scores.append({
			"value": val,
			"score": ruled_out_count
		})
	
	# Urutkan berdasarkan score terendah (least constraining first)
	value_scores.sort_custom(func(a, b): return a["score"] < b["score"])
	
	var sorted_values: Array = []
	for item in value_scores:
		sorted_values.append(item["value"])
	return sorted_values


# ==============================================================================
# 4. FORWARD CHECKING & AC-3 (ARC CONSISTENCY 3)
# ==============================================================================

## Forward Checking: Memangkas nilai domain tetangga yang tidak lagi konsisten dengan nilai yang baru saja di-assign
func forward_check(
	assigned_var: Vector2i,
	assigned_val: Dictionary,
	unassigned_vars: Array[Vector2i],
	current_domains: Dictionary,
	constraints: Dictionary,
	current_assignment: Dictionary
) -> Dictionary:
	var pruned_records: Array[Dictionary] = []
	var neighbors = get_constrained_neighbors(assigned_var, unassigned_vars, constraints)
	
	for neighbor in neighbors:
		if not (neighbor in unassigned_vars):
			continue
		
		var neighbor_domain: Array = current_domains[neighbor]
		var to_remove: Array = []
		
		for candidate_val in neighbor_domain:
			# Cek konsistensi binary dengan nilai yang baru di-assign
			if not is_binary_consistent(assigned_var, assigned_val, neighbor, candidate_val, constraints):
				to_remove.append(candidate_val)
				continue
			
			# Cek apakah penambahan candidate_val akan langsung melanggar batas atas global
			current_assignment[neighbor] = candidate_val
			var passes_global = is_global_consistent(current_assignment, constraints, true)
			current_assignment.erase(neighbor)
			
			if not passes_global:
				to_remove.append(candidate_val)
		
		for val in to_remove:
			neighbor_domain.erase(val)
			pruned_records.append({
				"var": neighbor,
				"val": val
			})
			pruned_values_count += 1
		
		# Jika domain tetangga menjadi kosong, telah terjadi domain wipeout
		if neighbor_domain.is_empty():
			return {
				"success": false,
				"pruned": pruned_records
			}
	
	return {
		"success": true,
		"pruned": pruned_records
	}

## Mengembalikan nilai-nilai domain yang dipangkas saat backtracking mundur
func restore_pruned_values(current_domains: Dictionary, pruned_records: Array[Dictionary]) -> void:
	for record in pruned_records:
		var var_pos: Vector2i = record["var"]
		var val: Dictionary = record["val"]
		if current_domains.has(var_pos):
			if not (val in current_domains[var_pos]):
				current_domains[var_pos].append(val)

## Algoritma AC-3 (Arc Consistency 3) untuk memangkas inkonsistensi domain secara global
func run_ac3(all_vars: Array[Vector2i], current_domains: Dictionary, constraints: Dictionary) -> bool:
	var queue: Array = []
	for xi in all_vars:
		var neighbors = get_constrained_neighbors(xi, all_vars, constraints)
		for xj in neighbors:
			queue.append([xi, xj])
	
	while not queue.is_empty():
		var arc: Array = queue.pop_front()
		var xi: Vector2i = arc[0]
		var xj: Vector2i = arc[1]
		
		if revise_arc(xi, xj, current_domains, constraints):
			ac3_revisions_count += 1
			if current_domains[xi].is_empty():
				return false # Domain wipeout: CSP tidak satisfiable
			
			var xi_neighbors = get_constrained_neighbors(xi, all_vars, constraints)
			for xk in xi_neighbors:
				if xk != xj:
					queue.append([xk, xi])
	
	return true

## Fungsi pembantu AC-3 untuk merevisi relasi busur (xi, xj)
func revise_arc(xi: Vector2i, xj: Vector2i, current_domains: Dictionary, constraints: Dictionary) -> bool:
	var revised: bool = false
	var to_remove: Array = []
	
	for x_val in current_domains[xi]:
		var has_support: bool = false
		for y_val in current_domains[xj]:
			if is_binary_consistent(xi, x_val, xj, y_val, constraints):
				has_support = true
				break
		if not has_support:
			to_remove.append(x_val)
			revised = true
	
	for val in to_remove:
		current_domains[xi].erase(val)
	return revised


# ==============================================================================
# 5. BACKTRACKING SEARCH DENGAN MRV + DEGREE + AC-3 + FORWARD CHECKING
# ==============================================================================

## Menjalankan pencarian solusi penempatan menggunakan Backtracking Search
func solve_backtracking(
	variables: Array[Vector2i],
	domains: Dictionary,
	constraints: Dictionary,
	use_ac3_preprocess: bool = true,
	use_forward_checking: bool = true
) -> Dictionary:
	var t0 = Time.get_ticks_msec()
	backtrack_steps = 0
	pruned_values_count = 0
	ac3_revisions_count = 0
	
	# Salin domain agar tidak mengubah input asli
	var working_domains: Dictionary = {}
	for v in variables:
		var dom_list: Array = []
		if domains.has(v):
			for item in domains[v]:
				# Pangkas nilai awal yang melanggar constraint Unary
				if is_unary_consistent(v, item, constraints):
					dom_list.append(item)
		working_domains[v] = dom_list
	
	# Jalankan AC-3 preprocessing jika diaktifkan
	if use_ac3_preprocess:
		var ac3_ok = run_ac3(variables, working_domains, constraints)
		if not ac3_ok:
			execution_time_ms = Time.get_ticks_msec() - t0
			return {
				"success": false,
				"method": "BACKTRACKING_AC3",
				"assignment": {},
				"steps": backtrack_steps,
				"time_ms": execution_time_ms,
				"error": "AC-3 mendeteksi domain kosong (unsatisfiable constraint)."
			}
	
	var unassigned: Array[Vector2i] = []
	unassigned.append_array(variables)
	var assignment: Dictionary = {}
	
	var success = _backtrack_recursive(
		assignment,
		unassigned,
		working_domains,
		variables,
		constraints,
		use_forward_checking
	)
	
	execution_time_ms = Time.get_ticks_msec() - t0
	return {
		"success": success,
		"method": "BACKTRACKING_MRV_DEGREE_FC",
		"assignment": assignment if success else {},
		"steps": backtrack_steps,
		"pruned_values": pruned_values_count,
		"ac3_revisions": ac3_revisions_count,
		"time_ms": execution_time_ms
	}

func _backtrack_recursive(
	assignment: Dictionary,
	unassigned_vars: Array[Vector2i],
	current_domains: Dictionary,
	all_vars: Array[Vector2i],
	constraints: Dictionary,
	use_forward_checking: bool
) -> bool:
	backtrack_steps += 1
	
	# Base Case: Semua variabel telah diberi nilai assignment
	if unassigned_vars.is_empty():
		return is_global_consistent(assignment, constraints, false)
	
	# Pilih variabel menggunakan MRV & Degree Heuristic
	var selected_var: Vector2i = select_unassigned_variable_mrv(
		unassigned_vars,
		current_domains,
		all_vars,
		constraints
	)
	
	# Buat list nilai domain dengan ordering LCV
	var domain_values: Array = current_domains.get(selected_var, [])
	var ordered_values: Array = order_domain_values_lcv(
		selected_var,
		domain_values,
		unassigned_vars,
		current_domains,
		constraints
	)
	
	unassigned_vars.erase(selected_var)
	
	for val in ordered_values:
		# 1. Validasi Unary
		if not is_unary_consistent(selected_var, val, constraints):
			continue
		
		# 2. Validasi Binary terhadap variabel yang sudah di-assign
		var binary_consistent: bool = true
		for assigned_slot in assignment:
			if not is_binary_consistent(selected_var, val, assigned_slot, assignment[assigned_slot], constraints):
				binary_consistent = false
				break
		if not binary_consistent:
			continue
		
		# 3. Validasi Global Parsial
		assignment[selected_var] = val
		if not is_global_consistent(assignment, constraints, true):
			assignment.erase(selected_var)
			continue
		
		# 4. Forward Checking jika diaktifkan
		var fc_result: Dictionary = {"success": true, "pruned": []}
		if use_forward_checking:
			fc_result = forward_check(
				selected_var,
				val,
				unassigned_vars,
				current_domains,
				constraints,
				assignment
			)
		
		if fc_result["success"]:
			var sub_success = _backtrack_recursive(
				assignment,
				unassigned_vars,
				current_domains,
				all_vars,
				constraints,
				use_forward_checking
			)
			if sub_success:
				return true
		
		# Rollback Forward Checking dan assignment jika cabang ini gagal
		if not fc_result["pruned"].is_empty():
			restore_pruned_values(current_domains, fc_result["pruned"])
		assignment.erase(selected_var)
	
	# Kembalikan variabel ke unassigned list saat backtrack mundur
	unassigned_vars.append(selected_var)
	return false


# ==============================================================================
# 6. LOCAL SEARCH CSP: MIN-CONFLICTS (solve_min_conflicts)
# ==============================================================================

## Menghitung jumlah konflik untuk satu variabel dalam assignment saat ini
func count_variable_conflicts(
	var_pos: Vector2i,
	candidate_val: Dictionary,
	current_assignment: Dictionary,
	constraints: Dictionary
) -> int:
	var conflicts: int = 0
	
	# 1. Cek konflik Unary
	if not is_unary_consistent(var_pos, candidate_val, constraints):
		conflicts += 10
	
	# 2. Cek konflik Binary dengan variabel lain
	for other_pos in current_assignment:
		if other_pos == var_pos:
			continue
		var other_val: Dictionary = current_assignment[other_pos]
		if not is_binary_consistent(var_pos, candidate_val, other_pos, other_val, constraints):
			conflicts += 1
	
	# 3. Cek penalti Global
	current_assignment[var_pos] = candidate_val
	if not is_global_consistent(current_assignment, constraints, false):
		conflicts += 3
	
	return conflicts

## Menghitung total konflik pada keseluruhan assignment
func count_total_conflicts(assignment: Dictionary, constraints: Dictionary) -> int:
	var total: int = 0
	var slots: Array = assignment.keys()
	
	for i in range(slots.size()):
		var slot_a = slots[i]
		var val_a = assignment[slot_a]
		if not is_unary_consistent(slot_a, val_a, constraints):
			total += 5
		
		for j in range(i + 1, slots.size()):
			var slot_b = slots[j]
			var val_b = assignment[slot_b]
			if not is_binary_consistent(slot_a, val_a, slot_b, val_b, constraints):
				total += 1
	
	if not is_global_consistent(assignment, constraints, false):
		total += 3
	return total

## Algoritma Local Search Min-Conflicts untuk memperbaiki konfigurasi yang melanggar constraint
func solve_min_conflicts(
	variables: Array[Vector2i],
	domains: Dictionary,
	constraints: Dictionary,
	max_steps: int = 500,
	initial_assignment: Dictionary = {}
) -> Dictionary:
	var t0 = Time.get_ticks_msec()
	var current_assignment: Dictionary = {}
	
	# Setup konfigurasi awal jika belum disediakan
	if not initial_assignment.is_empty():
		for v in variables:
			if initial_assignment.has(v):
				current_assignment[v] = initial_assignment[v]
			else:
				var dom: Array = domains.get(v, [create_domain_entry("empty")])
				current_assignment[v] = dom[randi() % dom.size()]
	else:
		# Inisialisasi Greedy acak
		for v in variables:
			var dom: Array = domains.get(v, [create_domain_entry("empty")])
			var best_init_val = dom[0]
			var min_c: int = 9999
			for candidate in dom:
				var c = count_variable_conflicts(v, candidate, current_assignment, constraints)
				if c < min_c:
					min_c = c
					best_init_val = candidate
			current_assignment[v] = best_init_val
	
	var best_assignment = current_assignment.duplicate(true)
	var best_conflicts = count_total_conflicts(current_assignment, constraints)
	
	if best_conflicts == 0:
		execution_time_ms = Time.get_ticks_msec() - t0
		return {
			"success": true,
			"method": "MIN_CONFLICTS",
			"assignment": current_assignment,
			"steps": 0,
			"conflicts": 0,
			"time_ms": execution_time_ms
		}
	
	for step in range(max_steps):
		# Kumpulkan semua variabel yang saat ini berkonflik
		var conflicted_vars: Array[Vector2i] = []
		for v in variables:
			var c = count_variable_conflicts(v, current_assignment[v], current_assignment, constraints)
			if c > 0:
				conflicted_vars.append(v)
		
		# Jika tidak ada variabel yang berkonflik dan lolos global check, solusi ditemukan
		if conflicted_vars.is_empty() and is_global_consistent(current_assignment, constraints, false):
			best_assignment = current_assignment.duplicate(true)
			best_conflicts = 0
			execution_time_ms = Time.get_ticks_msec() - t0
			return {
				"success": true,
				"method": "MIN_CONFLICTS",
				"assignment": current_assignment,
				"steps": step + 1,
				"conflicts": 0,
				"time_ms": execution_time_ms
			}
		
		# Pilih salah satu variabel berkonflik secara acak
		var chosen_var: Vector2i = conflicted_vars[randi() % conflicted_vars.size()] if not conflicted_vars.is_empty() else variables[randi() % variables.size()]
		var dom_choices: Array = domains.get(chosen_var, [])
		
		# Cari nilai domain yang meminimalkan konflik
		var min_c: int = 99999
		var best_values: Array = []
		
		for candidate_val in dom_choices:
			var old_val = current_assignment[chosen_var]
			current_assignment[chosen_var] = candidate_val
			var c = count_total_conflicts(current_assignment, constraints)
			current_assignment[chosen_var] = old_val
			
			if c < min_c:
				min_c = c
				best_values.clear()
				best_values.append(candidate_val)
			elif c == min_c:
				best_values.append(candidate_val)
		
		if not best_values.is_empty():
			current_assignment[chosen_var] = best_values[randi() % best_values.size()]
		
		var cur_total = count_total_conflicts(current_assignment, constraints)
		if cur_total < best_conflicts:
			best_conflicts = cur_total
			best_assignment = current_assignment.duplicate(true)
			if best_conflicts == 0 and is_global_consistent(best_assignment, constraints, false):
				execution_time_ms = Time.get_ticks_msec() - t0
				return {
					"success": true,
					"method": "MIN_CONFLICTS",
					"assignment": best_assignment,
					"steps": step + 1,
					"conflicts": 0,
					"time_ms": execution_time_ms
				}
	
	execution_time_ms = Time.get_ticks_msec() - t0
	return {
		"success": (best_conflicts == 0),
		"method": "MIN_CONFLICTS",
		"assignment": best_assignment,
		"steps": max_steps,
		"conflicts": best_conflicts,
		"time_ms": execution_time_ms
	}


# ==============================================================================
# 7. INTEGRASI HELPER FUNCTION: ARENA SOLVER & SPAWNER
# ==============================================================================

## Membaca status arena saat ini dari GridManager, membentuk formulasi CSP, dan mengembalikan penempatan musuh yang valid
func solve_arena_placement(grid_manager: GridManager, options: Dictionary = {}) -> Dictionary:
	if not grid_manager:
		push_warning("[CSPSolver] grid_manager null, tidak dapat menjalankan CSP.")
		return {"success": false, "error": "grid_manager_null"}
	
	var active_lantai: TileMapLayer = grid_manager.lantai if grid_manager.lantai else grid_manager.get_node_or_null("lantai")
	if not active_lantai:
		push_warning("[CSPSolver] active_lantai null pada GridManager.")
		return {"success": false, "error": "lantai_null"}
	
	# Dapatkan posisi Player di grid
	var player_pos: Vector2i = Vector2i(-9999, -9999)
	var player_node: Node2D = null
	if options.has("player_node"):
		player_node = options["player_node"]
	elif grid_manager.get_tree():
		player_node = grid_manager.get_tree().get_first_node_in_group("player")
	
	if player_node:
		player_pos = active_lantai.local_to_map(player_node.global_position)
	
	# Ekstraksi slot kandidat yang passable dan bebas dari duri statis
	var candidate_slots: Array[Vector2i] = []
	if options.has("candidate_slots") and not options["candidate_slots"].is_empty():
		for slot in options["candidate_slots"]:
			candidate_slots.append(slot as Vector2i)
	else:
		var all_passable: Array[Vector2i] = []
		for cell in active_lantai.get_used_cells():
			if grid_manager.is_passable(cell) and not grid_manager.duri_cells.has(cell):
				var dist_p = absi(cell.x - player_pos.x) + absi(cell.y - player_pos.y)
				if dist_p >= int(options.get("min_player_distance", 3)):
					all_passable.append(cell)
		
		# Pilih sampel slot kandidat yang tersebar di arena (misal 8 - 14 slot)
		all_passable.shuffle()
		var slot_sample_size: int = mini(all_passable.size(), int(options.get("max_candidate_slots", 10)))
		for i in range(slot_sample_size):
			candidate_slots.append(all_passable[i])
	
	if candidate_slots.is_empty():
		return {"success": false, "error": "no_candidate_slots"}
	
	# Bangun batasan Constraints
	var constraints: Dictionary = {
		"player_pos": player_pos,
		"min_player_distance": int(options.get("min_player_distance", 3)),
		"min_enemy_distance": int(options.get("min_enemy_distance", 4)),
		"min_duri_distance": int(options.get("min_duri_distance", 2)),
		"min_enemy_duri_distance": int(options.get("min_enemy_duri_distance", 2)),
		"min_elite_distance": int(options.get("min_elite_distance", 5)),
		"max_total_hp": float(options.get("max_total_hp", 350.0)),
		"max_total_damage": float(options.get("max_total_damage", 120.0)),
		"min_enemies": int(options.get("min_enemies", 2)),
		"max_enemies": int(options.get("max_enemies", 4)),
		"min_duri": int(options.get("min_duri", 0)),
		"max_duri": int(options.get("max_duri", 2)),
		"existing_duri_cells": grid_manager.duri_cells
	}
	
	# Bangun Domain untuk setiap variabel slot
	var allowed_types: Array = options.get("allowed_types", ["Skeleton", "Orc", "Goblin", "Knight", "duri", "empty"])
	var base_domain: Array[Dictionary] = create_default_domain(allowed_types, true)
	
	var domains: Dictionary = {}
	for slot in candidate_slots:
		domains[slot] = base_domain.duplicate(true)
	
	# Jalankan algoritma yang dipilih (Backtracking atau Min-Conflicts)
	var solver_method: String = options.get("method", "BACKTRACKING").to_upper()
	var solve_result: Dictionary
	
	if solver_method == "MIN_CONFLICTS":
		var max_steps: int = int(options.get("max_steps", 600))
		solve_result = solve_min_conflicts(candidate_slots, domains, constraints, max_steps)
	else:
		var use_ac3: bool = bool(options.get("use_ac3", true))
		var use_fc: bool = bool(options.get("use_forward_checking", true))
		solve_result = solve_backtracking(candidate_slots, domains, constraints, use_ac3, use_fc)
	
	if not solve_result.get("success", false):
		return solve_result
	
	# Olah pemetaan hasil penempatan musuh dan duri
	var assignment: Dictionary = solve_result.get("assignment", {})
	var enemy_placements: Array[Dictionary] = []
	var duri_placements: Array[Dictionary] = []
	var total_hp: float = 0.0
	var total_dmg: float = 0.0
	
	for slot in assignment:
		var val: Dictionary = assignment[slot]
		if val.get("is_enemy", false):
			enemy_placements.append({
				"grid_pos": slot,
				"config": val
			})
			total_hp += float(val.get("hp", 0.0))
			total_dmg += float(val.get("damage", 0.0))
		elif val.get("is_duri", false):
			duri_placements.append({
				"grid_pos": slot,
				"cost": float(val.get("cost", 10.0))
			})
	
	solve_result["enemy_placements"] = enemy_placements
	solve_result["duri_placements"] = duri_placements
	solve_result["summary"] = {
		"enemy_count": enemy_placements.size(),
		"duri_count": duri_placements.size(),
		"total_hp": total_hp,
		"total_damage": total_dmg,
		"slots_evaluated": candidate_slots.size()
	}
	
	return solve_result

## Meneruskan data penempatan CSP ke GridManager dan BattleManager guna melakukan spawning node musuh secara otomatis
func spawn_enemies_from_csp(
	grid_manager: GridManager,
	battle_manager: BattleManager = null,
	placement_result: Dictionary = {}
) -> Array:
	var spawned_nodes: Array = []
	if not grid_manager:
		return spawned_nodes
	
	# Jika placement_result belum dihitung, jalankan solver secara otomatis
	if placement_result.is_empty() or not placement_result.get("success", false):
		placement_result = solve_arena_placement(grid_manager)
	
	if not placement_result.get("success", false):
		push_warning("[CSPSolver] Gagal melakukan spawning karena CSP placement tidak sukses.")
		return spawned_nodes
	
	var active_lantai: TileMapLayer = grid_manager.lantai if grid_manager.lantai else grid_manager.get_node_or_null("lantai")
	var entities_parent: Node = grid_manager.get_node_or_null("entities")
	if not entities_parent:
		entities_parent = grid_manager
	
	var player_node: Node2D = grid_manager.get_tree().get_first_node_in_group("player") if grid_manager.get_tree() else null
	var debug_node: Node = grid_manager.get_node_or_null("PathfindingDebug")
	var battle_mgr: Node = battle_manager if battle_manager else (grid_manager.get_tree().get_first_node_in_group("battle_manager") if grid_manager.get_tree() else null)
	
	var enemy_placements: Array = placement_result.get("enemy_placements", [])
	var duri_placements: Array = placement_result.get("duri_placements", [])
	
	# 1. Spawning Entitas Musuh
	var enemy_scene: PackedScene = load("res://scenes/enemy.tscn")
	var skeleton_scene: PackedScene = load("res://scenes/skeleton.tscn") if ResourceLoader.exists("res://scenes/skeleton.tscn") else null
	var enemy_script = load("res://scripts/enemy.gd")
	
	for i in range(enemy_placements.size()):
		var entry: Dictionary = enemy_placements[i]
		var grid_pos: Vector2i = entry.get("grid_pos", Vector2i.ZERO)
		var config: Dictionary = entry.get("config", {})
		var type_name: String = config.get("type", "Enemy")
		
		var chosen_scene: PackedScene = enemy_scene
		if type_name == "Skeleton" and skeleton_scene:
			chosen_scene = skeleton_scene
		
		if not chosen_scene:
			continue
		
		var enemy_instance = chosen_scene.instantiate() as CharacterBody2D
		if not enemy_instance:
			continue
		
		# Pasang script jika scene belum memiliki script enemy
		if enemy_instance.get_script() == null and enemy_script:
			enemy_instance.set_script(enemy_script)
		
		# Tentukan posisi spawn berdasarkan koordinat grid
		var spawn_pos: Vector2 = active_lantai.map_to_local(grid_pos) if active_lantai else Vector2(grid_pos * 32)
		enemy_instance.global_position = spawn_pos
		
		# Tautkan dependensi node
		enemy_instance.set("tilemap_layer", active_lantai)
		enemy_instance.set("grid_manager", grid_manager)
		enemy_instance.set("player", player_node)
		enemy_instance.set("debug_node", debug_node)
		enemy_instance.set("battle_manager", battle_mgr)
		
		# Simpan metadata konfigurasi CSP pada node
		enemy_instance.set_meta("npc_config", config)
		enemy_instance.name = "CSP_NPC_%s_%d" % [type_name, i + 1]
		
		entities_parent.add_child(enemy_instance)
		spawned_nodes.append(enemy_instance)
	
	# 2. Spawning Hazard Duri jika ada dan daftarkan ke GridManager
	var duri_scene: PackedScene = load("res://scenes/duri.tscn") if ResourceLoader.exists("res://scenes/duri.tscn") else null
	for duri_entry in duri_placements:
		var d_pos: Vector2i = duri_entry.get("grid_pos", Vector2i.ZERO)
		var d_cost: float = float(duri_entry.get("cost", 10.0))
		grid_manager.register_duri(d_pos, d_cost)
		
		if duri_scene:
			var duri_instance = duri_scene.instantiate() as Node2D
			if duri_instance:
				duri_instance.global_position = active_lantai.map_to_local(d_pos) if active_lantai else Vector2(d_pos * 32)
				duri_instance.set("tilemap_layer", active_lantai)
				duri_instance.set("grid_manager", grid_manager)
				duri_instance.set("duri_cost", d_cost)
				entities_parent.add_child(duri_instance)
	
	# 3. Teruskan data statistik musuh pertama ke BattleManager jika tersedia
	if battle_mgr and not enemy_placements.is_empty():
		if battle_mgr.has_method("apply_optimized_npc_config_to_battle"):
			battle_mgr.apply_optimized_npc_config_to_battle(enemy_placements[0].get("config", {}))
	
	return spawned_nodes

## Melakukan benchmark komparasi algoritma Backtracking (MRV + Degree + AC-3) vs Min-Conflicts Local Search
func benchmark_csp_algorithms(grid_manager: GridManager, options: Dictionary = {}) -> Dictionary:
	var opt_bt = options.duplicate()
	opt_bt["method"] = "BACKTRACKING"
	opt_bt["use_ac3"] = true
	opt_bt["use_forward_checking"] = true
	
	var opt_mc = options.duplicate()
	opt_mc["method"] = "MIN_CONFLICTS"
	opt_mc["max_steps"] = int(options.get("max_steps", 600))
	
	print("\n=======================================================")
	print("[Tubes Tahap 4] BENCHMARK CSP ENEMY PLACEMENT")
	print("=======================================================")
	
	var res_bt = solve_arena_placement(grid_manager, opt_bt)
	print("Backtracking (MRV + Degree + AC-3 + FC):")
	print("  Success     : ", res_bt.get("success", false))
	print("  Waktu       : %d ms" % res_bt.get("time_ms", 0))
	print("  Langkah/Node: ", res_bt.get("steps", 0))
	print("  Summary     : ", res_bt.get("summary", {}))
	
	var res_mc = solve_arena_placement(grid_manager, opt_mc)
	print("\nMin-Conflicts (Local Search CSP):")
	print("  Success     : ", res_mc.get("success", false))
	print("  Waktu       : %d ms" % res_mc.get("time_ms", 0))
	print("  Steps       : ", res_mc.get("steps", 0))
	print("  Conflicts   : ", res_mc.get("conflicts", 0))
	print("  Summary     : ", res_mc.get("summary", {}))
	print("=======================================================\n")
	
	return {
		"backtracking": res_bt,
		"min_conflicts": res_mc
	}
