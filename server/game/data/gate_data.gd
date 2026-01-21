class_name GateData
extends RefCounted

## Gate Data Manager
## Loads and provides access to Gate configurations from gates.json

static var _gates: Array = []
static var _loaded: bool = false

## Load all gates from registry
static func load_gates() -> void:
	if _loaded:
		return
		
	var file = FileAccess.open("res://data/gates.json", FileAccess.READ)
	if not file:
		print("❌ Failed to open gates.json")
		return
	
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(content)
	
	if error == OK:
		_gates = json.data
		_loaded = true
		print("✅ Loaded %d gate definitions" % _gates.size())
	else:
		print("❌ JSON Parse Error: ", json.get_error_message())

## Get all gates belonging to a specific map
static func get_gates_for_map(map_id: int) -> Array:
	if not _loaded:
		load_gates()
	
	var result = []
	for gate in _gates:
		if gate.get("belong_map_id") == map_id:
			result.append(gate)
	
	return result

## Get a specific gate by ID
static func get_gate(gate_id: int) -> Dictionary:
	if not _loaded:
		load_gates()
	
	for gate in _gates:
		if gate.get("id") == gate_id:
			return gate
	
	print("⚠️ Gate not found: ", gate_id)
	return {}

## Get full gate data merged with map gate override
static func get_merged_gate_data(gate_id: int, override: Dictionary) -> Dictionary:
	var base = get_gate(gate_id)
	if base.is_empty():
		return {}
	
	# Merge override into base (override takes precedence)
	var merged = base.duplicate()
	for key in override.keys():
		if key != "gate_id": # Don't override the reference key
			merged[key] = override[key]
	
	return merged
