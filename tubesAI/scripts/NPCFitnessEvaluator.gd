class_name NPCFitnessEvaluator
extends RefCounted

## Evaluator fungsi fitness untuk optimasi konfigurasi NPC (Tubes Tahap 3).
## Mengestimasi daya tempur (HP + Attack + Item) dari kombinasi NPC terhadap Player.
## Fitness bernilai 100.0 saat kekuatan seimbang dan berkurang jika terlalu kuat/lemah.

# Statistik dasar untuk tipe NPC
const NPC_TYPES: Dictionary = {
	"Orc": {
		"base_hp": 100.0,
		"base_attack": 20.0,
		"base_defense": 5.0,
		"desc": "Tipe standar dengan HP dan attack seimbang"
	},
	"Skeleton": {
		"base_hp": 70.0,
		"base_attack": 26.0,
		"base_defense": 2.0,
		"desc": "Penyerang cepat dengan attack tinggi dan HP rendah"
	},
	"Goblin": {
		"base_hp": 60.0,
		"base_attack": 16.0,
		"base_defense": 1.0,
		"desc": "Musuh berukuran kecil dengan atribut ringan"
	},
	"Knight": {
		"base_hp": 130.0,
		"base_attack": 16.0,
		"base_defense": 8.0,
		"desc": "Tipe tangguh dengan defense tinggi"
	}
}

# Bonus atribut item
const ITEM_CATALOG: Dictionary = {
	"NONE": {
		"hp_bonus": 0.0,
		"attack_bonus": 0.0,
		"defense_bonus": 0.0
	},
	"SWORD": {
		"hp_bonus": 0.0,
		"attack_bonus": 8.0,
		"defense_bonus": 0.0
	},
	"SHIELD": {
		"hp_bonus": 20.0,
		"attack_bonus": 0.0,
		"defense_bonus": 6.0
	},
	"POTION": {
		"hp_bonus": 25.0,
		"attack_bonus": 0.0,
		"defense_bonus": 0.0
	},
	"AXE": {
		"hp_bonus": 0.0,
		"attack_bonus": 12.0,
		"defense_bonus": -2.0
	},
	"ARMOR": {
		"hp_bonus": 35.0,
		"attack_bonus": -2.0,
		"defense_bonus": 8.0
	},
	"AMULET": {
		"hp_bonus": 15.0,
		"attack_bonus": 4.0,
		"defense_bonus": 2.0
	}
}

# Bobot estimasi kekuatan tempur (Combat Power)
const WEIGHT_HP: float = 0.6
const WEIGHT_ATTACK: float = 2.0
const WEIGHT_DEFENSE: float = 1.2

## Mengembalikan daftar nama tipe NPC yang tersedia
static func get_available_npc_types() -> Array:
	return NPC_TYPES.keys()

## Mengembalikan daftar nama item yang tersedia
static func get_available_items() -> Array:
	return ITEM_CATALOG.keys()

## Menghitung estimasi kekuatan Player dari Dictionary statistik
static func calculate_player_power(player_stats: Dictionary) -> float:
	var hp: float = float(player_stats.get("hp", 100))
	var attack: float = float(player_stats.get("attack", 20))
	var defense: float = float(player_stats.get("defense", 5))
	var potions: float = float(player_stats.get("potion", player_stats.get("potions", 2)))
	
	var effective_hp: float = maxf(1.0, hp + (potions * 25.0))
	var power: float = (effective_hp * WEIGHT_HP) + (attack * WEIGHT_ATTACK) + (defense * WEIGHT_DEFENSE)
	return maxf(1.0, power)

## Menghitung akumulasi statistik dan total Combat Power dari konfigurasi NPC
static func calculate_npc_total_power(npc_config: Array) -> Dictionary:
	var total_hp: float = 0.0
	var total_attack: float = 0.0
	var total_defense: float = 0.0
	
	for npc in npc_config:
		if not (npc is Dictionary):
			continue
		
		var npc_type: String = String(npc.get("type", "Orc"))
		var base_data: Dictionary = NPC_TYPES.get(npc_type, NPC_TYPES["Orc"])
		
		var base_hp: float = float(npc.get("base_hp", npc.get("hp", base_data["base_hp"])))
		var base_atk: float = float(npc.get("base_attack", npc.get("attack", base_data["base_attack"])))
		var base_def: float = float(npc.get("base_defense", npc.get("defense", base_data["base_defense"])))
		
		var item_hp: float = 0.0
		var item_atk: float = 0.0
		var item_def: float = 0.0
		
		var items = npc.get("items", [])
		if items is Array:
			for item_name in items:
				var it_key: String = String(item_name)
				if ITEM_CATALOG.has(it_key):
					var it_data: Dictionary = ITEM_CATALOG[it_key]
					item_hp += float(it_data.get("hp_bonus", 0.0))
					item_atk += float(it_data.get("attack_bonus", 0.0))
					item_def += float(it_data.get("defense_bonus", 0.0))
		
		var final_npc_hp: float = maxf(1.0, base_hp + item_hp)
		var final_npc_atk: float = maxf(1.0, base_atk + item_atk)
		var final_npc_def: float = maxf(0.0, base_def + item_def)
		
		total_hp += final_npc_hp
		total_attack += final_npc_atk
		total_defense += final_npc_def
	
	var total_power: float = (total_hp * WEIGHT_HP) + (total_attack * WEIGHT_ATTACK) + (total_defense * WEIGHT_DEFENSE)
	
	return {
		"total_hp": total_hp,
		"total_attack": total_attack,
		"total_defense": total_defense,
		"total_power": total_power
	}

## Menghitung nilai kelayakan (fitness) konfigurasi NPC terhadap Player
## Output bernilai 100.0 jika kekuatan seimbang sempurna, dan berkurang jika tidak seimbang.
static func evaluate_fitness(npc_config: Array, player_stats: Dictionary) -> float:
	if npc_config.is_empty():
		return 0.0
	
	var player_power: float = calculate_player_power(player_stats)
	var npc_stats: Dictionary = calculate_npc_total_power(npc_config)
	var npc_power: float = npc_stats["total_power"]
	
	var diff: float = absf(npc_power - player_power)
	var penalty: float = (diff / maxf(1.0, player_power)) * 100.0
	var fitness: float = maxf(0.0, 100.0 - penalty)
	
	return 0.0 if is_nan(fitness) else fitness
