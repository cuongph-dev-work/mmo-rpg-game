class_name MobData
extends Node

## Mob Data Manager
## Loads and provides access to Mob Templates

static var _templates: Dictionary = {}
static var _loaded: bool = false

static func load_templates():
	if _loaded: return
	
	var file = FileAccess.open("res://data/mobs/mob_templates.json", FileAccess.READ)
	if not file:
		print("❌ Failed to open mob_templates.json")
		return
		
	var content = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(content)
	
	if error == OK:
		var data = json.data
		if data.has("mobs"):
			_templates = data["mobs"]
			_loaded = true
			print("✅ Loaded %d mob templates" % _templates.size())
	else:
		print("❌ JSON Parse Error: ", json.get_error_message())

static func get_template(mob_id: String) -> Dictionary:
	if not _loaded:
		load_templates()
		
	if _templates.has(mob_id):
		return _templates[mob_id]
	
	print("⚠️  Mob template not found: ", mob_id)
	return {}
