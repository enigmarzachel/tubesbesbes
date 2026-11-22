class_name PropositionalInferenceEngine
extends RefCounted

## Forward-chaining propositional inference. Knowledge (rules) is supplied separately.
static func infer(initial_facts: Array[String], rules: Array[Dictionary]) -> Dictionary:
	var facts: Dictionary = {}
	for fact in initial_facts:
		facts[fact] = true
	var trace: Array[Dictionary] = []
	var changed := true
	while changed:
		changed = false
		for rule in rules:
			var satisfied := true
			for premise in rule.get("if", []):
				if not facts.has(String(premise)):
					satisfied = false
					break
			var conclusion := String(rule.get("then", ""))
			if satisfied and not conclusion.is_empty() and not facts.has(conclusion):
				facts[conclusion] = true
				trace.append({"rule": String(rule.get("name", "unnamed rule")), "fact": conclusion})
				changed = true
	return {"facts": facts, "trace": trace, "initial_facts": initial_facts.duplicate(), "rule_count": rules.size()}

static func ask(result: Dictionary, proposition: String) -> bool:
	return result.get("facts", {}).has(proposition)

## Truth-table model checking for the finite grounded propositional KB.
static func model_check(initial_facts: Array[String], rules: Array[Dictionary], query: String) -> Dictionary:
	var symbols: Dictionary = {}
	for fact in initial_facts:
		symbols[fact] = true
	for rule in rules:
		for premise in rule.get("if", []):
			symbols[String(premise)] = true
		symbols[String(rule.get("then", ""))] = true
	symbols[query] = true
	var names: Array = symbols.keys()
	if names.size() > 20:
		return {"entailed": false, "complete": false, "models_checked": 0, "kb_models": 0, "error": "Truth table dibatasi hingga 20 simbol."}
	var kb_models := 0
	var countermodels := 0
	var total := 1 << names.size()
	for mask in range(total):
		var model: Dictionary = {}
		for index in range(names.size()):
			model[names[index]] = (mask & (1 << index)) != 0
		if not _satisfies_kb(model, initial_facts, rules):
			continue
		kb_models += 1
		if not model.get(query, false):
			countermodels += 1
	return {"entailed": countermodels == 0, "complete": true, "models_checked": total, "kb_models": kb_models, "countermodels": countermodels}

## Resolution refutation for grounded Horn implications and positive facts.
static func resolution_entails(initial_facts: Array[String], rules: Array[Dictionary], query: String, clause_limit: int = 4096) -> Dictionary:
	var clauses: Array = []
	for fact in initial_facts:
		_add_clause(clauses, [String(fact)])
	for rule in rules:
		var clause: Array[String] = []
		for premise in rule.get("if", []):
			clause.append("!" + String(premise))
		clause.append(String(rule.get("then", "")))
		_add_clause(clauses, clause)
	_add_clause(clauses, ["!" + query])
	var trace: Array[String] = []
	var cursor := 0
	while cursor < clauses.size():
		var current: Array = clauses[cursor]
		for other_index in range(cursor):
			var other: Array = clauses[other_index]
			for literal in current:
				var opposite := _complement(String(literal))
				if opposite not in other:
					continue
				var resolvent: Array[String] = []
				for item in current:
					if item != literal and item not in resolvent:
						resolvent.append(String(item))
				for item in other:
					if item != opposite and item not in resolvent:
						resolvent.append(String(item))
				if _is_tautology(resolvent):
					continue
				if resolvent.is_empty():
					trace.append("Resolve %s with %s => □" % [_format_clause(current), _format_clause(other)])
					return {"entailed": true, "complete": true, "clauses": clauses.size(), "trace": trace}
				var before := clauses.size()
				_add_clause(clauses, resolvent)
				if clauses.size() > before:
					trace.append("%s + %s => %s" % [_format_clause(current), _format_clause(other), _format_clause(resolvent)])
					if clauses.size() >= clause_limit:
						return {"entailed": false, "complete": false, "clauses": clauses.size(), "trace": trace, "error": "Batas jumlah clause tercapai."}
		cursor += 1
	return {"entailed": false, "complete": true, "clauses": clauses.size(), "trace": trace}

static func _satisfies_kb(model: Dictionary, initial_facts: Array[String], rules: Array[Dictionary]) -> bool:
	for fact in initial_facts:
		if not model.get(fact, false):
			return false
	for rule in rules:
		var premises_true := true
		for premise in rule.get("if", []):
			if not model.get(String(premise), false):
				premises_true = false
				break
		if premises_true and not model.get(String(rule.get("then", "")), false):
			return false
	return true

static func _add_clause(clauses: Array, clause: Array) -> void:
	var unique: Array[String] = []
	for literal in clause:
		if String(literal) not in unique:
			unique.append(String(literal))
	unique.sort()
	var key := "|".join(PackedStringArray(unique))
	for existing in clauses:
		if "|".join(PackedStringArray(existing)) == key:
			return
	clauses.append(unique)

static func _complement(literal: String) -> String:
	return literal.substr(1) if literal.begins_with("!") else "!" + literal

static func _is_tautology(clause: Array[String]) -> bool:
	for literal in clause:
		if _complement(literal) in clause:
			return true
	return false

static func _format_clause(clause: Array) -> String:
	if clause.is_empty():
		return "□"
	var literals: Array[String] = []
	for literal in clause:
		literals.append(String(literal).replace("!", "¬"))
	return "(%s)" % " ∨ ".join(PackedStringArray(literals))
