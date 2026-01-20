extends Control

## Login Scene - Handle user authentication

# UI References
@onready var username_input = $CenterContainer/LoginPanel/MarginContainer/VBoxContainer/UsernameInput
@onready var password_input = $CenterContainer/LoginPanel/MarginContainer/VBoxContainer/PasswordInput
@onready var login_button = $CenterContainer/LoginPanel/MarginContainer/VBoxContainer/LoginButton
@onready var register_button = $CenterContainer/LoginPanel/MarginContainer/VBoxContainer/RegisterButton
@onready var status_label = $CenterContainer/LoginPanel/MarginContainer/VBoxContainer/StatusLabel
@onready var http_request = $HTTPRequest

# Request types
enum RequestType {LOGIN, REGISTER}
var current_request_type: RequestType

func _ready():
	print("[Login] Login scene ready")
	status_label.text = ""
	
	# Try to load saved auth state
	if AuthState.load_from_disk():
		if AuthState.has_character():
			_show_status("Restoring session... Skipping to Character Select", Color.GREEN)
			await get_tree().create_timer(0.5).timeout
			get_tree().change_scene_to_file("res://scenes/character_select/CharacterSelect.tscn")
			return
		else:
			_show_status("Session restored! Please select character.", Color.GREEN)
			await get_tree().create_timer(1.0).timeout
			get_tree().change_scene_to_file("res://scenes/character_select/CharacterSelect.tscn")
			return
	
	# Set default test credentials for easier testing
	username_input.text = "testuser"
	password_input.text = "test123"
	
	# Focus on username input
	username_input.grab_focus()

func _on_login_button_pressed():
	var username = username_input.text.strip_edges()
	var password = password_input.text
	
	if username.is_empty() or password.is_empty():
		_show_error("Please enter username and password")
		return
	
	_set_ui_enabled(false)
	_show_status("Logging in...", Color.WHITE)
	
	current_request_type = RequestType.LOGIN
	_send_auth_request("/auth/login", username, password)

func _on_register_button_pressed():
	var username = username_input.text.strip_edges()
	var password = password_input.text
	
	if username.is_empty() or password.is_empty():
		_show_error("Please enter username and password")
		return
	
	if password.length() < 6:
		_show_error("Password must be at least 6 characters")
		return
	
	_set_ui_enabled(false)
	_show_status("Creating account...", Color.WHITE)
	
	current_request_type = RequestType.REGISTER
	_send_auth_request("/auth/register", username, password)

func _send_auth_request(endpoint: String, username: String, password: String):
	var url = Config.get_auth_service_url() + endpoint
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"username": username,
		"password": password
	})
	
	print("[Login] Sending request to: %s" % url)
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		_show_error("Failed to send request: %s" % error)
		_set_ui_enabled(true)

func _on_http_request_completed(result, response_code, _headers, body):
	print("[Login] Request completed - Code: %d" % response_code)
	
	_set_ui_enabled(true)
	
	if result != HTTPRequest.RESULT_SUCCESS:
		_show_error("Connection failed. Please check if server is running.")
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		_show_error("Failed to parse server response")
		return
	
	var response_data = json.get_data()
	
	if response_code == 200 or response_code == 201:
		_on_auth_success(response_data)
	else:
		_on_auth_failure(response_data, response_code)

func _on_auth_success(data: Dictionary):
	var access_token = data.get("access_token", "")
	var user_id = data.get("user_id", "")
	
	if access_token.is_empty() or user_id.is_empty():
		_show_error("Invalid server response")
		return
	
	# Store authentication
	AuthState.set_auth(access_token, user_id)
	AuthState.save_to_disk() # 💾 Save for auto-login next time
	
	if current_request_type == RequestType.REGISTER:
		_show_status("Account created! Redirecting...", Color.GREEN)
	else:
		_show_status("Login successful! Redirecting...", Color.GREEN)
	
	# Wait a moment then transition to character select
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/character_select/CharacterSelect.tscn")

func _on_auth_failure(data: Dictionary, response_code: int):
	var error_message = data.get("message", "Unknown error")
	
	match response_code:
		401:
			_show_error("Invalid username or password")
		409:
			_show_error("Username already taken")
		_:
			_show_error("Error: %s" % error_message)

func _show_error(message: String):
	status_label.text = "❌ " + message
	status_label.add_theme_color_override("font_color", Color.RED)
	print("[Login] Error: %s" % message)

func _show_status(message: String, color: Color):
	status_label.text = message
	status_label.add_theme_color_override("font_color", color)

func _set_ui_enabled(enabled: bool):
	username_input.editable = enabled
	password_input.editable = enabled
	login_button.disabled = not enabled
	register_button.disabled = not enabled
