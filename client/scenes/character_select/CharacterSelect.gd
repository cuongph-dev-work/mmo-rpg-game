extends Control

## Character Select Scene - View and create characters, enter game world

# UI References
@onready var character_list = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/CharacterListScroll/CharacterList
@onready var create_button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ButtonContainer/CreateCharacterButton
@onready var enter_world_button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ButtonContainer/EnterWorldButton
@onready var status_label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/StatusLabel

# Popup UI
@onready var create_popup = $CreateCharacterPopup
@onready var name_input = $CreateCharacterPopup/MarginContainer/VBoxContainer/NameInput
@onready var class_option = $CreateCharacterPopup/MarginContainer/VBoxContainer/ClassOption
@onready var popup_status_label = $CreateCharacterPopup/MarginContainer/VBoxContainer/PopupStatusLabel

@onready var http_request = $HTTPRequest

# State
var characters: Array = []
var classes: Array = []
var selected_class_id: String = ""
var selected_character: Dictionary = {}
var selected_character_button: Button = null

# Request types
enum RequestType {FETCH_CHARACTERS, FETCH_CLASSES, CREATE_CHARACTER}
var current_request_type: RequestType

func _ready():
	print("[CharacterSelect] Character select scene ready")
	
	# Check authentication
	if not AuthState.is_authenticated():
		print("[CharacterSelect] Not authenticated, returning to login")
		get_tree().change_scene_to_file("res://scenes/login/Login.tscn")
		return
	
	# Listen to Gateway events
	GatewayClient.enter_world_success.connect(_on_enter_world_success)
	GatewayClient.gateway_error.connect(_on_gateway_error)
	
	# Initialize UI
	class_option.clear()
	
	# Fetch initial data
	_fetch_classes()

func _fetch_classes():
	status_label.text = "Loading classes..."
	var url = Config.get_auth_service_url() + "/character-classes"
	var headers = ["Authorization: " + AuthState.get_auth_header()]
	
	print("[CharacterSelect] Fetching classes from: %s" % url)
	current_request_type = RequestType.FETCH_CLASSES
	http_request.request(url, headers, HTTPClient.METHOD_GET)

func _fetch_characters():
	status_label.text = "Loading characters..."
	status_label.add_theme_color_override("font_color", Color.WHITE)
	
	var url = Config.get_auth_service_url() + "/characters"
	var headers = [
		"Content-Type: application/json",
		"Authorization: " + AuthState.get_auth_header()
	]
	
	print("[CharacterSelect] Fetching characters from: %s" % url)
	current_request_type = RequestType.FETCH_CHARACTERS
	var error = http_request.request(url, headers, HTTPClient.METHOD_GET)
	
	if error != OK:
		_show_error("Failed to fetch characters: %s" % error)

func _on_http_request_completed(result, response_code, _headers, body):
	print("[CharacterSelect] Request completed - Code: %d" % response_code)
	
	if result != HTTPRequest.RESULT_SUCCESS:
		_show_error("Connection failed. Please check if server is running.")
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		_show_error("Failed to parse server response")
		print("Response body: %s" % body.get_string_from_utf8())
		return
	
	var response_data = json.get_data()
	
	match current_request_type:
		RequestType.FETCH_CLASSES:
			_on_classes_fetched(response_code, response_data)
		RequestType.FETCH_CHARACTERS:
			_on_characters_fetched(response_code, response_data)
		RequestType.CREATE_CHARACTER:
			_on_character_created(response_code, response_data)

func _on_classes_fetched(response_code: int, data):
	if response_code == 200:
		classes = data if typeof(data) == TYPE_ARRAY else []
		_display_classes()
		# After classes are loaded, fetch characters
		_fetch_characters()
	else:
		_show_error("Failed to fetch character classes")

func _display_classes():
	class_option.clear()
	for i in range(classes.size()):
		var cls = classes[i]
		class_option.add_item(cls.get("name", "Unknown"))
		# Store the class index as metadata or just use index to lookup in array
		# We'll use the index to look up the class object in the `classes` array

func _on_confirm_button_pressed():
	var char_name = name_input.text.strip_edges()
	var selected_index = class_option.selected
	
	if selected_index < 0 or selected_index >= classes.size():
		popup_status_label.text = "❌ Please select a class"
		popup_status_label.add_theme_color_override("font_color", Color.RED)
		return
		
	var selected_class = classes[selected_index]
	var class_id = selected_class.get("id")
	
	if char_name.is_empty():
		popup_status_label.text = "❌ Please enter a character name"
		popup_status_label.add_theme_color_override("font_color", Color.RED)
		return
	
	if char_name.length() < 3:
		popup_status_label.text = "❌ Name must be at least 3 characters"
		popup_status_label.add_theme_color_override("font_color", Color.RED)
		return
	
	_create_character(char_name, class_id)

func _create_character(char_name: String, class_id: String):
	popup_status_label.text = "Creating character..."
	popup_status_label.add_theme_color_override("font_color", Color.WHITE)
	
	var url = Config.get_auth_service_url() + "/characters"
	var headers = [
		"Content-Type: application/json",
		"Authorization: " + AuthState.get_auth_header()
	]
	var body = JSON.stringify({
		"name": char_name,
		"class_id": class_id
	})
	
	print("[CharacterSelect] Creating character: %s (Class ID: %s)" % [char_name, class_id])
	current_request_type = RequestType.CREATE_CHARACTER
	http_request.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_characters_fetched(response_code: int, data):
	if response_code == 200:
		characters = data if typeof(data) == TYPE_ARRAY else []
		_display_characters()
		
		if characters.is_empty():
			status_label.text = "No characters yet. Create your first character!"
		else:
			status_label.text = "%d character(s) found. Select one to enter the world." % characters.size()
	else:
		_show_error("Failed to fetch characters")

func _display_characters():
	# Clear existing character buttons
	for child in character_list.get_children():
		child.queue_free()
	
	# Create button for each character
	for char_data in characters:
		var button = Button.new()
		button.custom_minimum_size = Vector2(0, 60)
		button.text = "%s (Lv.%d - Class %s)" % [
			char_data.get("name", "Unknown"),
			char_data.get("level", 1),
			char_data.get("class_name")
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_character_button_pressed.bind(button, char_data))
		character_list.add_child(button)

func _on_character_button_pressed(button: Button, char_data: Dictionary):
	# Deselect previous
	if selected_character_button:
		selected_character_button.modulate = Color.WHITE
	
	# Select new
	selected_character = char_data
	selected_character_button = button
	button.modulate = Color(0.7, 1.0, 0.7)
	
	# Enable enter world button
	enter_world_button.disabled = false
	
	print("[CharacterSelect] Selected character: %s (ID: %s)" % [char_data.get("name"), char_data.get("id")])

func _on_create_character_button_pressed():
	name_input.text = ""
	popup_status_label.text = ""
	create_popup.show()

func _on_cancel_button_pressed():
	create_popup.hide()


func _on_character_created(response_code: int, data):
	if response_code == 201:
		popup_status_label.text = "✅ Character created!"
		popup_status_label.add_theme_color_override("font_color", Color.GREEN)
		
		await get_tree().create_timer(1.0).timeout
		create_popup.hide()
		
		# Refresh character list
		_fetch_characters()
	else:
		var error_message = data.get("message", "Unknown error")
		popup_status_label.text = "❌ " + error_message
		popup_status_label.add_theme_color_override("font_color", Color.RED)

func _on_enter_world_button_pressed():
	if selected_character.is_empty():
		_show_error("No character selected")
		return
	
	var character_id = selected_character.get("id", "")
	if character_id.is_empty():
		_show_error("Invalid character")
		return
	
	# Store character in AuthState
	AuthState.set_character(character_id, selected_character)
	
	# Connect to Gateway
	status_label.text = "Connecting to Gateway..."
	_set_ui_enabled(false)
	
	print("[CharacterSelect] Connecting to Gateway...")
	GatewayClient.connect_to_gateway(AuthState.access_token)
	
	# Wait for connection
	await GatewayClient.gateway_connected
	
	status_label.text = "Sending enter_world request..."
	print("[CharacterSelect] Gateway connected, sending enter_world...")
	GatewayClient.send_enter_world(character_id)

func _on_enter_world_success(data: Dictionary):
	print("[CharacterSelect] Enter world successful! Data: %s" % data)
	
	# Store map server allocation data for World scene to use
	AuthState.map_server_data = data
	
	status_label.text = "✅ Entering world..."
	status_label.add_theme_color_override("font_color", Color.GREEN)
	
	# Change scene immediately so World can connect to Map Server
	get_tree().change_scene_to_file("res://scenes/world/World.tscn")

func _on_gateway_error(error: Dictionary):
	var error_message = error.get("message", "Unknown error")
	_show_error("Gateway error: %s" % error_message)
	_set_ui_enabled(true)

func _show_error(message: String):
	status_label.text = "❌ " + message
	status_label.add_theme_color_override("font_color", Color.RED)
	print("[CharacterSelect] Error: %s" % message)

func _set_ui_enabled(enabled: bool):
	create_button.disabled = not enabled
	enter_world_button.disabled = not enabled or selected_character.is_empty()
