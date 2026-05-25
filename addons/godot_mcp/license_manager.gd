@tool
extends RefCounted

## License Manager for Hunyusang Godot MCP Pro
## Handles online verification, machine binding, and token caching.

const LICENSE_SERVER_HTTPS := "https://82.156.14.125/mcp-license/api/verify"
const LICENSE_SERVER_HTTP := "http://82.156.14.125/mcp-license/api/verify"
const CACHE_FILE := "user://hunyusang_mcp_license_cache.json"
const LICENSE_INPUT_FILE := "res://addons/godot_mcp/.license_key"
const CACHE_VERSION := "1"

var _cached_token: String = ""
var _token_expiry: int = 0
var _license_key: String = ""
var _is_verified: bool = false
var _last_error: String = ""

signal verification_completed(success: bool, error: String)

func _init():
	_load_cache()

## Check if currently authorized (cached token still valid)
func is_authorized() -> bool:
	return _is_verified and _is_token_valid()

## Get last error message
func get_last_error() -> String:
	return _last_error

## Get current license key
func get_license_key() -> String:
	return _license_key

## Main verification entry point
func verify() -> bool:
	# 1. Check cached token
	if _is_token_valid():
		_is_verified = true
		_last_error = ""
		return true

	# 2. Read license key from file
	_license_key = _read_license_key()
	if _license_key.is_empty():
		_last_error = "LICENSE_FILE_NOT_FOUND"
		_is_verified = false
		return false

	# 3. Request server verification
	var result = await _request_verify(_license_key)

	if result.valid:
		_cached_token = result.get("token", "")
		var expires_in: int = result.get("expires_in", 604800)
		_token_expiry = int(Time.get_unix_time_from_system()) + expires_in
		_save_cache()
		_is_verified = true
		_last_error = ""
		print("[MCP Pro] License verified successfully")
		return true
	else:
		_cached_token = ""
		_token_expiry = 0
		_is_verified = false
		_last_error = result.get("error", "UNKNOWN_ERROR")
		var message: String = result.get("message", "")
		if not message.is_empty():
			_last_error += ": " + message
		push_error("[MCP Pro] License verification failed: " + _last_error)
		return false

## Read license key from .license_key file
func _read_license_key() -> String:
	if not FileAccess.file_exists(LICENSE_INPUT_FILE):
		return ""
	var file := FileAccess.open(LICENSE_INPUT_FILE, FileAccess.READ)
	if not file:
		return ""
	var raw := file.get_buffer(file.get_length())
	var content: String = ""
	# Handle UTF-16 LE BOM (Windows Script Host default)
	if raw.size() >= 2 and raw[0] == 0xFF and raw[1] == 0xFE:
		# Skip BOM, decode as UTF-16 LE (2 bytes per char)
		var i := 2
		while i + 1 < raw.size():
			var code := raw.decode_u16(i)
			if code == 0:
				break
			content += String.chr(code)
			i += 2
	else:
		content = raw.get_string_from_utf8()
	content = content.strip_edges()
	# Remove any whitespace or newlines
	return content.replace(" ", "").replace("\n", "").replace("\r", "")

## Send verification request to license server
func _request_verify(license_key: String) -> Dictionary:
	var machine_id := _get_machine_id()
	var body := JSON.stringify({
		"license": license_key,
		"machine_id": machine_id,
		"version": _get_plugin_version()
	})
	print("[MCP Pro] Request body: ", body)

	# Strategy 1: Use system curl (most reliable, uses OS network stack)
	for use_https in [true, false]:
		var url := LICENSE_SERVER_HTTPS if use_https else LICENSE_SERVER_HTTP
		print("[MCP Pro] Trying curl ", "HTTPS" if use_https else "HTTP", " -> ", url)
		var result := _do_curl_request(url, body)
		if result.get("error") != "CURL_NOT_FOUND" and result.get("error") != "TIMEOUT" and result.get("error") != "CURL_FAILED":
			return result
		print("[MCP Pro] curl failed: ", result.get("error"), " - ", result.get("message"))

	# Strategy 2: Fallback to Godot HTTPRequest
	for use_https in [true, false]:
		var url := LICENSE_SERVER_HTTPS if use_https else LICENSE_SERVER_HTTP
		print("[MCP Pro] Trying Godot HTTPRequest ", "HTTPS" if use_https else "HTTP", " -> ", url)
		var result := await _do_http_request(url, body)
		if result.get("error") != "TIMEOUT" and result.get("error") != "NETWORK_INIT_FAILED":
			return result
		print("[MCP Pro] HTTPRequest failed: ", result.get("error"), " - ", result.get("message"))

	return {"valid": false, "error": "TIMEOUT", "message": "Server did not respond via HTTPS or HTTP"}


func _do_curl_request(url: String, body: String) -> Dictionary:
	var curl_cmd := "curl"
	if OS.get_name() == "Windows":
		# Strategy 1a: Try Windows curl.exe first (Windows 10+ has it)
		# Write body to temp file to avoid Windows command-line quoting issues
		var temp_path := OS.get_user_data_dir() + "/mcp_license_request.json"
		var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
		if temp_file == null:
			print("[MCP Pro] Failed to create temp file: ", temp_path)
			return {"valid": false, "error": "CURL_FAILED", "message": "Cannot write temp file"}
		temp_file.store_string(body)
		temp_file.close()

		var curl_args: PackedStringArray = [
			"-k", "-s", "-X", "POST",
			"-H", "Content-Type: application/json",
			"-d", "@" + temp_path,
			"-m", "10",
			"-w", "\\nHTTP_CODE:%{http_code}",
			url
		]
		var curl_output: Array = []
		var curl_exit := OS.execute("curl.exe", curl_args, curl_output, true)
		print("[MCP Pro] curl.exe exit code: ", curl_exit)
		if curl_exit == 0 and not curl_output.is_empty():
			var response_text: String = curl_output[0].strip_edges()
			var http_code_idx := response_text.rfind("HTTP_CODE:")
			if http_code_idx != -1:
				var http_code := response_text.substr(http_code_idx + 10).to_int()
				var json_text := response_text.substr(0, http_code_idx).strip_edges()
				print("[MCP Pro] curl.exe HTTP code: ", http_code)
				var json := JSON.new()
				var parse_err := json.parse(json_text)
				if parse_err == OK:
					return json.get_data()
				else:
					return {"valid": false, "error": "HTTP_ERROR", "message": "Server returned status " + str(http_code)}
		print("[MCP Pro] curl.exe exit code non-zero, falling back to PowerShell")

		# Strategy 1b: Fallback to PowerShell Invoke-WebRequest
		curl_cmd = "powershell"
		var ps_body := body.replace('"', '\\"')
		var args: PackedStringArray = [
				"-Command",
				"$bp=Get-Content -Raw '" + temp_path + "'; try { $r = iwr -Uri '" + url + "' -Method POST -Headers @{\"Content-Type\"=\"application/json\"} -Body $bp -TimeoutSec 10; $r.Content } catch { if ($_.Exception.Response) { $s=$_.Exception.Response.GetResponseStream(); $rdr=New-Object IO.StreamReader($s); $rdr.ReadToEnd() } else { \"NET_ERROR:\"+$_.Exception.Message } }"
		]
		var output: Array = []
		var exit_code := OS.execute(curl_cmd, args, output, true)
		if exit_code != 0 or output.is_empty():
			return {"valid": false, "error": "CURL_FAILED", "message": "PowerShell request failed (code: " + str(exit_code) + ")"}
		var response_text: String = output[0].strip_edges()
		if response_text.begins_with("NET_ERROR:"):
			return {"valid": false, "error": "CURL_FAILED", "message": response_text.substr(10)}
		var json := JSON.new()
		var parse_err := json.parse(response_text)
		if parse_err != OK:
			return {"valid": false, "error": "PARSE_ERROR", "message": "Invalid JSON response"}
		return json.get_data()
	else:
		# Unix-like: use curl with temp file to avoid argument passing issues on macOS
		var temp_path := OS.get_user_data_dir() + "/mcp_license_request.json"
		var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
		if temp_file == null:
			return {"valid": false, "error": "CURL_FAILED", "message": "Cannot write temp file"}
		temp_file.store_string(body)
		temp_file.close()

		var args: PackedStringArray = [
			"-k", "-s", "-X", "POST",
			"-H", "Content-Type: application/json",
			"-d", "@" + temp_path,
			"-m", "10",
			"-w", "\nHTTP_CODE:%{http_code}",
			url
		]
		var output: Array = []
		var exit_code := OS.execute(curl_cmd, args, output, true)
		print("[MCP Pro] curl exit code: ", exit_code)
		if exit_code != 0 or output.is_empty():
			return {"valid": false, "error": "CURL_FAILED", "message": "curl request failed (code: " + str(exit_code) + ")"}
		var response_text: String = output[0].strip_edges()
		print("[MCP Pro] curl raw response: ", response_text)
		var http_code_idx := response_text.rfind("HTTP_CODE:")
		if http_code_idx == -1:
			return {"valid": false, "error": "CURL_FAILED", "message": "Invalid curl response format"}
		var http_code := response_text.substr(http_code_idx + 10).to_int()
		print("[MCP Pro] curl HTTP code: ", http_code)
		var json_text := response_text.substr(0, http_code_idx).strip_edges()
		if http_code != 200:
			return {"valid": false, "error": "HTTP_ERROR", "message": "Server returned status " + str(http_code)}
		var json := JSON.new()
		var parse_err := json.parse(json_text)
		if parse_err != OK:
			return {"valid": false, "error": "PARSE_ERROR", "message": "Invalid JSON response"}
		return json.get_data()


func _do_http_request(url: String, body: String) -> Dictionary:
	var http := HTTPRequest.new()
	var temp_node := Node.new()
	temp_node.name = "LicenseHTTP"
	Engine.get_main_loop().root.add_child(temp_node)
	temp_node.add_child(http)

	# Temporary: skip TLS cert validation for IP-based access (cert CN is nanalongai.top, not IP)
	http.tls_options = TLSOptions.client_unsafe()

	var err := http.request(
		url,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)

	if err != OK:
		push_warning("[MCP Pro] HTTP request init failed: " + str(err))
		temp_node.queue_free()
		return {"valid": false, "error": "NETWORK_INIT_FAILED", "message": "HTTP request creation failed (code: " + str(err) + ")"}

	var timeout_timer := Timer.new()
	timeout_timer.wait_time = 10.0
	timeout_timer.one_shot = true
	temp_node.add_child(timeout_timer)
	timeout_timer.start()

	var response_data: Dictionary = {}
	var received := false

	http.request_completed.connect(
		func(result: int, status: int, _headers: PackedStringArray, response_body: PackedByteArray):
			received = true
			print("[MCP Pro] HTTP result code: ", result, " | HTTP status: ", status)
			if result != HTTPRequest.RESULT_SUCCESS:
				var err_names := {
					HTTPRequest.RESULT_CANT_CONNECT: "CANT_CONNECT",
					HTTPRequest.RESULT_CANT_RESOLVE: "CANT_RESOLVE",
					HTTPRequest.RESULT_CONNECTION_ERROR: "CONNECTION_ERROR",
					HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: "TLS_HANDSHAKE_ERROR",
					HTTPRequest.RESULT_NO_RESPONSE: "NO_RESPONSE"
				}
				var err_name: String = err_names.get(result, "UNKNOWN(" + str(result) + ")")
				response_data = {
					"valid": false,
					"error": err_name,
					"message": "HTTP request failed with result: " + err_name
				}
				return
			if status != 200:
				response_data = {
					"valid": false,
					"error": "HTTP_ERROR",
					"message": "Server returned status " + str(status)
				}
				return

			var json := JSON.new()
			var parse_err := json.parse(response_body.get_string_from_utf8())
			if parse_err != OK:
				response_data = {
					"valid": false,
					"error": "PARSE_ERROR",
					"message": "Invalid server response"
				}
				return

			response_data = json.get_data()
	)

	while not received and timeout_timer.time_left > 0:
		await Engine.get_main_loop().create_timer(0.1).timeout

	if not received:
		response_data = {
			"valid": false,
			"error": "TIMEOUT",
			"message": "Server did not respond within 10 seconds"
		}

	temp_node.queue_free()
	return response_data

## Generate machine fingerprint
func _get_machine_id() -> String:
	var components: Array[String] = [
		OS.get_name(),
		OS.get_processor_name(),
		OS.get_unique_id()
	]
	var combined := "|".join(components)
	return combined.md5_text()

## Get plugin version from plugin.cfg
func _get_plugin_version() -> String:
	var cfg := ConfigFile.new()
	if cfg.load("res://addons/godot_mcp/plugin.cfg") == OK:
		return cfg.get_value("plugin", "version", "unknown")
	return "unknown"

## Token cache management
func _load_cache() -> void:
	if not FileAccess.file_exists(CACHE_FILE):
		return

	var file := FileAccess.open(CACHE_FILE, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		return

	var data: Variant = json.get_data()
	if not data is Dictionary:
		return

	var dict: Dictionary = data
	# Validate cache version
	if dict.get("version") != CACHE_VERSION:
		return

	_cached_token = dict.get("token", "")
	_token_expiry = dict.get("expiry", 0)
	_license_key = dict.get("license", "")

func _save_cache() -> void:
	var file := FileAccess.open(CACHE_FILE, FileAccess.WRITE)
	var data := {
		"version": CACHE_VERSION,
		"token": _cached_token,
		"expiry": _token_expiry,
		"license": _license_key
	}
	file.store_string(JSON.stringify(data))

func _is_token_valid() -> bool:
	if _cached_token.is_empty() or _token_expiry <= 0:
		return false
	var now := int(Time.get_unix_time_from_system())
	return now < _token_expiry

## Clear cached data (for debugging or reset)
func clear_cache() -> void:
	_cached_token = ""
	_token_expiry = 0
	_license_key = ""
	_is_verified = false
	if FileAccess.file_exists(CACHE_FILE):
		DirAccess.remove_absolute(CACHE_FILE)
