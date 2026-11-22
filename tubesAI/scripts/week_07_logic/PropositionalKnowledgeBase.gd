class_name PropositionalKnowledgeBase
extends RefCounted

## Declarative rule set for NPC-to-NPC tactical coordination.
## Each rule is an implication: all `if` facts imply the `then` fact.
const RULES: Array[Dictionary] = [
	{"name": "R0: player nearby => engage player", "if": ["PLAYER_NEARBY"], "then": "ENGAGE_PLAYER"},
	{"name": "R1: ally chasing + player nearby => support ally", "if": ["ALLY_CHASING_PLAYER", "PLAYER_NEARBY"], "then": "SUPPORT_ALLY"},
	{"name": "R2: ally nearby + player nearby => coordinate assault", "if": ["ALLY_NEARBY", "PLAYER_NEARBY"], "then": "COORDINATED_ASSAULT"},
	{"name": "R3: elite + ally nearby => coordinate assault", "if": ["ELITE_NPC", "ALLY_NEARBY"], "then": "COORDINATED_ASSAULT"}
]

static func get_rules() -> Array[Dictionary]:
	var copied_rules: Array[Dictionary] = []
	copied_rules.append_array(RULES)
	return copied_rules
