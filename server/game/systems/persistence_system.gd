class_name PersistenceSystem
extends Node

## Persistence System
## Handles all HTTP communication with the Backend for saving/loading player data.
## Extracts this complexity from the main GameServer.

signal state_loaded(character_id: String, state: Dictionary)
signal state_saved(character_id: String)
signal save_failed(character_id: String, error_code: int)

var auth_service_url: String = "http://localhost:3000"
var requests_pool: Node

func setup():
	name = "PersistenceSystem"
	requests_pool = Node.new()
	requests_pool.name = "RequestsPool"
	add_child(requests_pool)
	
	var env_url = OS.get_environment("AUTH_SERVICE_URL")
	if not env_url.is_empty():
		auth_service_url = env_url
	
	print("💾 Persistence System Initialized (Backend: %s)" % auth_service_url)

func load_player_state(character_id: String, callback: Callable = Callable()):
	var url = "%s/characters/%s/internal" % [auth_service_url, character_id]
	print("📥 Fetching state for %s..." % character_id)
	
	_make_request(url, HTTPClient.METHOD_GET, [], "", func(code, body):
		if code == 200:
			var json = JSON.parse_string(body.get_string_from_utf8())
			if json:
				state_loaded.emit(character_id, json)
				if callback.is_valid(): callback.call(json)
				return
		
		print("⚠️ Failed to load state for %s (Code: %d)" % [character_id, code])
		if callback.is_valid(): callback.call({})
	)

func save_player_state(character_id: String, data: Dictionary):
	var url = "%s/characters/%s/internal" % [auth_service_url, character_id]
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify(data)
	
	print("💾 Saving state for %s..." % character_id)
	
	_make_request(url, HTTPClient.METHOD_PATCH, headers, body, func(code, _body):
		if code >= 200 and code < 300:
			print("✅ State saved for %s" % character_id)
			state_saved.emit(character_id)
		else:
			print("❌ Failed to save state for %s (Code: %d)" % [character_id, code])
			save_failed.emit(character_id, code)
	)

func _make_request(url: String, method: int, headers: PackedStringArray, body: String, callback: Callable):
	var request = HTTPRequest.new()
	requests_pool.add_child(request)
	
	request.request_completed.connect(func(_res, code, _headers, resp_body):
		callback.call(code, resp_body)
		request.queue_free()
	)
	
	var error = request.request(url, headers, method, body)
	if error != OK:
		print("❌ HTTP Request failed to start: %s" % error)
		request.queue_free()
