extends CanvasLayer

var options_scene = preload("res://scenes/ui/options_menu.tscn")

func _ready():
	# 连接按钮
	$%PlayButton.pressed.connect(on_play_pressed)
	$%UpgradesButton.pressed.connect(on_upgrades_pressed)
	$%OptionsButton.pressed.connect(on_options_pressed)
	$%QuitButton.pressed.connect(on_quit_pressed)
	
	# 应用赛博朋克样式
	_apply_cyberpunk_styles()
	
	print("✅ 菜单已准备就绪")

func _apply_cyberpunk_styles():
	"""应用赛博朋克配色"""
	# PlayButton - 深粉色
	var play_normal = StyleBoxFlat.new()
	play_normal.bg_color = Color.html("#FF1493")
	play_normal.corner_radius_top_left = 6
	play_normal.corner_radius_top_right = 6
	play_normal.corner_radius_bottom_left = 6
	play_normal.corner_radius_bottom_right = 6
	play_normal.border_color = Color.html("#FF1493").lightened(0.2)
	play_normal.border_width_left = 2
	play_normal.border_width_right = 2
	play_normal.border_width_top = 2
	play_normal.border_width_bottom = 2
	
	var play_hover = StyleBoxFlat.new()
	play_hover.bg_color = Color.html("#FF69B4")
	play_hover.corner_radius_top_left = 6
	play_hover.corner_radius_top_right = 6
	play_hover.corner_radius_bottom_left = 6
	play_hover.corner_radius_bottom_right = 6
	play_hover.border_color = Color.html("#FF69B4").lightened(0.3)
	play_hover.border_width_left = 3
	play_hover.border_width_right = 3
	play_hover.border_width_top = 3
	play_hover.border_width_bottom = 3
	
	$%PlayButton.add_theme_stylebox_override("normal", play_normal)
	$%PlayButton.add_theme_stylebox_override("hover", play_hover)
	$%PlayButton.add_theme_color_override("font_color", Color.WHITE)
	$%PlayButton.add_theme_color_override("font_hover_color", Color.WHITE)
	
	# UpgradesButton - 暗绿松石色
	var upgrades_normal = StyleBoxFlat.new()
	upgrades_normal.bg_color = Color.html("#00CED1")
	upgrades_normal.corner_radius_top_left = 6
	upgrades_normal.corner_radius_top_right = 6
	upgrades_normal.corner_radius_bottom_left = 6
	upgrades_normal.corner_radius_bottom_right = 6
	upgrades_normal.border_color = Color.html("#00CED1").lightened(0.2)
	upgrades_normal.border_width_left = 2
	upgrades_normal.border_width_right = 2
	upgrades_normal.border_width_top = 2
	upgrades_normal.border_width_bottom = 2
	
	var upgrades_hover = StyleBoxFlat.new()
	upgrades_hover.bg_color = Color.html("#00FFFF")
	upgrades_hover.corner_radius_top_left = 6
	upgrades_hover.corner_radius_top_right = 6
	upgrades_hover.corner_radius_bottom_left = 6
	upgrades_hover.corner_radius_bottom_right = 6
	upgrades_hover.border_color = Color.html("#00FFFF").lightened(0.3)
	upgrades_hover.border_width_left = 3
	upgrades_hover.border_width_right = 3
	upgrades_hover.border_width_top = 3
	upgrades_hover.border_width_bottom = 3
	
	$%UpgradesButton.add_theme_stylebox_override("normal", upgrades_normal)
	$%UpgradesButton.add_theme_stylebox_override("hover", upgrades_hover)
	$%UpgradesButton.add_theme_color_override("font_color", Color.BLACK)
	$%UpgradesButton.add_theme_color_override("font_hover_color", Color.BLACK)
	
	# OptionsButton - 深紫色
	var options_normal = StyleBoxFlat.new()
	options_normal.bg_color = Color.html("#9932CC")
	options_normal.corner_radius_top_left = 6
	options_normal.corner_radius_top_right = 6
	options_normal.corner_radius_bottom_left = 6
	options_normal.corner_radius_bottom_right = 6
	options_normal.border_color = Color.html("#9932CC").lightened(0.2)
	options_normal.border_width_left = 2
	options_normal.border_width_right = 2
	options_normal.border_width_top = 2
	options_normal.border_width_bottom = 2
	
	var options_hover = StyleBoxFlat.new()
	options_hover.bg_color = Color.html("#BA55D3")
	options_hover.corner_radius_top_left = 6
	options_hover.corner_radius_top_right = 6
	options_hover.corner_radius_bottom_left = 6
	options_hover.corner_radius_bottom_right = 6
	options_hover.border_color = Color.html("#BA55D3").lightened(0.3)
	options_hover.border_width_left = 3
	options_hover.border_width_right = 3
	options_hover.border_width_top = 3
	options_hover.border_width_bottom = 3
	
	$%OptionsButton.add_theme_stylebox_override("normal", options_normal)
	$%OptionsButton.add_theme_stylebox_override("hover", options_hover)
	$%OptionsButton.add_theme_color_override("font_color", Color.WHITE)
	$%OptionsButton.add_theme_color_override("font_hover_color", Color.WHITE)
	
	# QuitButton - 橙红色
	var quit_normal = StyleBoxFlat.new()
	quit_normal.bg_color = Color.html("#FF4500")
	quit_normal.corner_radius_top_left = 6
	quit_normal.corner_radius_top_right = 6
	quit_normal.corner_radius_bottom_left = 6
	quit_normal.corner_radius_bottom_right = 6
	quit_normal.border_color = Color.html("#FF4500").lightened(0.2)
	quit_normal.border_width_left = 2
	quit_normal.border_width_right = 2
	quit_normal.border_width_top = 2
	quit_normal.border_width_bottom = 2
	
	var quit_hover = StyleBoxFlat.new()
	quit_hover.bg_color = Color.html("#FF6347")
	quit_hover.corner_radius_top_left = 6
	quit_hover.corner_radius_top_right = 6
	quit_hover.corner_radius_bottom_left = 6
	quit_hover.corner_radius_bottom_right = 6
	quit_hover.border_color = Color.html("#FF6347").lightened(0.3)
	quit_hover.border_width_left = 3
	quit_hover.border_width_right = 3
	quit_hover.border_width_top = 3
	quit_hover.border_width_bottom = 3
	
	$%QuitButton.add_theme_stylebox_override("normal", quit_normal)
	$%QuitButton.add_theme_stylebox_override("hover", quit_hover)
	$%QuitButton.add_theme_color_override("font_color", Color.WHITE)
	$%QuitButton.add_theme_color_override("font_hover_color", Color.WHITE)
	
	print("✓ 所有按钮已应用赛博朋克样式")

func on_play_pressed():
	print("🎮 进入游戏...")
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func on_upgrades_pressed():
	print("⬆️ 升级菜单...")
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	get_tree().change_scene_to_file("res://scenes/ui/meta_menu.tscn")

func on_options_pressed():
	print("⚙️ 选项菜单...")
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	var options_instance = options_scene.instantiate()
	add_child(options_instance)
	options_instance.back_pressed.connect(on_options_closed.bind(options_instance))

func on_quit_pressed():
	print("❌ 退出游戏")
	get_tree().quit()

func on_options_closed(options_instance: Node):
	options_instance.queue_free()
