@tool
extends EditorPlugin

const _MCP_AUTOLOADS: Array[Array] = [
	["autoload/MCPScreenshot", "res://addons/godot_mcp/mcp_screenshot_service.gd"],
	["autoload/MCPInputService", "res://addons/godot_mcp/mcp_input_service.gd"],
	["autoload/MCPGameInspector", "res://addons/godot_mcp/mcp_game_inspector_service.gd"],
]

const _MCP_TEMP_FILES: Array[String] = [
	"mcp_game_request",
	"mcp_game_response",
	"mcp_input_commands",
	"mcp_screenshot_request",
]

var websocket_server: Node
var command_router: Node
var status_panel: Control
var auto_dismiss_dialogs: bool = false
# Track which autoloads THIS session injected (vs project-owned)
var _session_injected_autoloads: Array[String] = []

# License management
var _license_manager: RefCounted
var _is_authorized: bool = false
var _activation_dialog: AcceptDialog

func _enter_tree() -> void:
	# ============================================================
	# LICENSE VERIFICATION (deferred to avoid blocking EditorPlugin init)
	# ============================================================
	_license_manager = preload("res://addons/godot_mcp/license_manager.gd").new()
	_check_license.call_deferred()


func _check_license() -> void:
	print("[MCP Pro] Checking license...")
	var license_valid = await _license_manager.verify()

	if not license_valid:
		_is_authorized = false
		_show_activation_dialog()
		return

	_is_authorized = true
	print("[MCP Pro] License verified. Initializing plugin...")
	# Show brief success popup so buyers know activation worked
	var success_dialog := AcceptDialog.new()
	success_dialog.title = "MCP Pro - 激活成功"
	success_dialog.dialog_text = "License 验证通过，插件已启用。\n\n如遇问题请联系闲鱼: hunyusang"
	success_dialog.exclusive = false
	var base_ctrl := EditorInterface.get_base_control()
	base_ctrl.add_child(success_dialog)
	success_dialog.popup_centered(Vector2(400, 180))
	success_dialog.confirmed.connect(func(): success_dialog.queue_free())
	_init_plugin_after_auth()


func _show_activation_dialog() -> void:
	var error_msg = _license_manager.get_last_error()

	var dialog := AcceptDialog.new()
	dialog.title = "MCP Pro - 需要激活"
	dialog.exclusive = false

	var msg := "[MCP Pro] 插件未激活\n\n"
	if error_msg == "LICENSE_FILE_NOT_FOUND":
		msg += "请在 addons/godot_mcp/ 目录下创建 .license_key 文件\n"
		msg += "并将你的许可证密钥粘贴到该文件中。\n\n"
	else:
		msg += "验证失败: " + error_msg + "\n\n"

	msg += "购买请联系闲鱼: hunyusang"

	dialog.dialog_text = msg
	dialog.dialog_hide_on_ok = true

	# Add retry button
	dialog.add_button("重试验证", true, "retry")
	dialog.custom_action.connect(
		func(action: StringName):
			if action == "retry":
				dialog.hide()
				_license_manager.clear_cache()
				var valid = await _license_manager.verify()
				if valid:
					_is_authorized = true
					if _activation_dialog:
						_activation_dialog.queue_free()
						_activation_dialog = null
					_init_plugin_after_auth()
				else:
					_show_activation_dialog()
	)

	var base := EditorInterface.get_base_control()
	base.add_child(dialog)
	dialog.popup_centered(Vector2(520, 280))
	_activation_dialog = dialog


func _init_plugin_after_auth() -> void:
	"""Initialize plugin components after successful license activation."""
	# Create command router
	command_router = preload("res://addons/godot_mcp/command_router.gd").new()
	command_router.name = "MCPCommandRouter"
	command_router.editor_plugin = self
	command_router.is_authorized = true
	add_child(command_router)

	# Create WebSocket server
	websocket_server = preload("res://addons/godot_mcp/websocket_server.gd").new()
	websocket_server.name = "MCPWebSocketServer"
	websocket_server.command_router = command_router
	add_child(websocket_server)

	# Create status panel
	var panel_scene: PackedScene = preload("res://addons/godot_mcp/ui/status_panel.tscn")
	status_panel = panel_scene.instantiate()
	add_control_to_bottom_panel(status_panel, "MCP Pro")
	status_panel.call_deferred("setup", websocket_server, command_router)

	# Inject MCP autoloads into project settings
	_inject_autoloads()

	websocket_server.start_server()
	var cfg := ConfigFile.new()
	var ver := "unknown"
	if cfg.load("res://addons/godot_mcp/plugin.cfg") == OK:
		ver = cfg.get_value("plugin", "version", "unknown")
	print("[MCP] Godot MCP Pro v%s started (ports 6505-6514)" % ver)


func _exit_tree() -> void:
	# Remove MCP autoloads and clean up temp files
	_remove_autoloads()
	_cleanup_temp_files()

	if websocket_server:
		websocket_server.stop_server()

	if status_panel:
		remove_control_from_bottom_panel(status_panel)
		status_panel.queue_free()

	if command_router:
		command_router.queue_free()

	if websocket_server:
		websocket_server.queue_free()

	print("[MCP] Godot MCP Pro stopped")


func _inject_autoloads() -> void:
	_session_injected_autoloads.clear()
	var changed := false
	for entry: Array in _MCP_AUTOLOADS:
		var key: String = entry[0]
		var script: String = entry[1]
		if not ProjectSettings.has_setting(key):
			ProjectSettings.set_setting(key, "*" + script)
			_session_injected_autoloads.append(key)
			changed = true
	if changed:
		ProjectSettings.save()


func _remove_autoloads() -> void:
	# Only remove autoloads that THIS session injected.
	# Pre-existing project-owned autoloads are preserved.
	var changed := false
	for key: String in _session_injected_autoloads:
		if ProjectSettings.has_setting(key):
			ProjectSettings.set_setting(key, null)
			changed = true
	_session_injected_autoloads.clear()
	if changed:
		ProjectSettings.save()


var _dialog_check_timer: float = 0.0
const _DIALOG_CHECK_INTERVAL: float = 0.5  # Check every 0.5 seconds

func _process(delta: float) -> void:
	# Check if game inspector requested debugger continue
	var flag_path := OS.get_user_data_dir() + "/mcp_debugger_continue"
	if FileAccess.file_exists(flag_path):
		DirAccess.remove_absolute(flag_path)
		_try_debugger_continue()

	# Periodically check for blocking editor dialogs (only when enabled by AI)
	if auto_dismiss_dialogs:
		_dialog_check_timer += delta
		if _dialog_check_timer >= _DIALOG_CHECK_INTERVAL:
			_dialog_check_timer = 0.0
			_auto_dismiss_dialogs()


func _try_debugger_continue() -> void:
	# Last resort: find and press the debugger Continue button to unstick the game
	var base: Node = EditorInterface.get_base_control()
	var continue_btn := _find_debugger_continue_button(base)
	if continue_btn and continue_btn.visible and not continue_btn.disabled:
		continue_btn.emit_signal("pressed")
		push_warning("[MCP] Auto-pressed debugger Continue button")
	else:
		push_warning("[MCP] Could not find debugger Continue button")


func _find_debugger_continue_button(node: Node) -> Button:
	# Search for the Continue button in ScriptEditorDebugger
	if node is Button:
		var btn: Button = node
		if btn.tooltip_text.contains("Continue") or btn.text == "Continue":
			return btn
	for child in node.get_children():
		var found: Button = _find_debugger_continue_button(child)
		if found:
			return found
	return null


func _auto_dismiss_dialogs() -> void:
	var base: Node = EditorInterface.get_base_control()
	if not base:
		return
	_find_and_dismiss_dialogs(base)


func _find_and_dismiss_dialogs(node: Node) -> void:
	if node is AcceptDialog and node.visible:
		var dialog: AcceptDialog = node
		# Never dismiss file dialogs or non-modal popups
		if dialog is FileDialog:
			return
		if not dialog.exclusive:
			return
		# Get dialog title/text for logging
		var title := dialog.title
		var text := dialog.dialog_text
		# Accept the dialog (presses OK / confirms)
		dialog.get_ok_button().emit_signal("pressed")
		push_warning("[MCP] Auto-dismissed editor dialog: '%s' — %s" % [title, text])
		return  # One dialog per check cycle to avoid side effects

	for child in node.get_children():
		# Only search visible Windows to keep the scan lightweight
		if child is Window and not child.visible:
			continue
		_find_and_dismiss_dialogs(child)


func _cleanup_temp_files() -> void:
	var user_dir := OS.get_user_data_dir()
	for filename: String in _MCP_TEMP_FILES:
		var path := user_dir + "/" + filename
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	# Also clean up screenshot image
	var screenshot_path := user_dir + "/mcp_screenshot.png"
	if FileAccess.file_exists(screenshot_path):
		DirAccess.remove_absolute(screenshot_path)
