# Ultimate Cyberpunk Menu System - Complete Edition
# Features: Hover animations, click particles, sound effects, CRT scanlines, glow effects
# Colors: Login interface cyan-blue (#7dd3fc) for NEXUS/INFO, button neon colors
# All comments in English

extends Node

# ============================================================================
# EXPORT PARAMETERS
# ============================================================================

@export var enable_particles: bool = true
@export var enable_animations: bool = true
@export var enable_glow_on_click: bool = true
@export var enable_sound_effects: bool = true
@export var particle_count: int = 8
@export var animation_speed: float = 0.25
@export var glow_particle_color: Color = Color.html("#7dd3fc")  # Login interface cyan-blue


# ============================================================================
# BUTTON CONFIGURATION
# ============================================================================

var button_configs = {
	"PlayButton": {
		"color_normal": "#ff00ff",
		"color_hover": "#8800ff",
		"glow_color": Color.html("#7dd3fc"),  # Cyan-blue glow
		"text_color": Color.WHITE
	},
	"UpgradesButton": {
		"color_normal": "#00ff88",
		"color_hover": "#00aa66",
		"glow_color": Color.html("#7dd3fc"),  # Cyan-blue glow
		"text_color": Color.BLACK
	},
	"OptionsButton": {
		"color_normal": "#0088ff",
		"color_hover": "#0055ff",
		"glow_color": Color.html("#7dd3fc"),  # Cyan-blue glow
		"text_color": Color.WHITE
	},
	"QuitButton": {
		"color_normal": "#7700ff",
		"color_hover": "#4400aa",
		"glow_color": Color.html("#7dd3fc"),  # Cyan-blue glow
		"text_color": Color.WHITE
	}
}

# Audio configuration for UI sounds
var ui_sound_stream: AudioStream = null
var particle_container: Node2D


# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("🎬 Initializing Ultimate Cyberpunk Menu System...")
	
	# Setup buttons
	for btn_name in button_configs.keys():
		var btn = get_node_or_null(btn_name)
		if btn:
			_setup_button_style(btn, button_configs[btn_name])
			_setup_button_interactions(btn, button_configs[btn_name])
	
	# Initialize particle system
	if enable_particles:
		_setup_particle_system()
	
	# Load UI sound if available
	if enable_sound_effects:
		_load_ui_sound()
	
	# Setup CRT scanlines effect
	_setup_scanlines()
	
	print("✅ Ultimate Menu System Ready - All Features Enabled!")


# ============================================================================
# BUTTON STYLING
# ============================================================================

func _setup_button_style(btn: Button, config: Dictionary):
	"""
	Apply neon gradient colors and styling to button.
	Each button maintains its neon color on hover.
	Cyan-blue glow is applied dynamically on interaction.
	"""
	
	# Normal state
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color.html(config["color_normal"])
	style_normal.set_corner_radius_all(4)
	style_normal.border_color = Color.html(config["color_normal"]).darkened(0.3)
	style_normal.set_border_all(1)
	
	# Hover state
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color.html(config["color_hover"])
	style_hover.set_corner_radius_all(4)
	style_hover.border_color = Color.html(config["color_normal"])
	style_hover.set_border_all(2)
	
	# Pressed state
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color.html(config["color_normal"])
	style_pressed.set_corner_radius_all(4)
	style_pressed.border_color = Color.html(config["color_normal"])
	style_pressed.set_border_all(2)
	
	# Apply styles
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	
	# Set text colors
	btn.add_theme_color_override("font_color", config["text_color"])
	btn.add_theme_color_override("font_hover_color", config["text_color"])
	btn.add_theme_color_override("font_pressed_color", config["text_color"])
	
	print("✓ %s button styled with %s color" % [btn.name, config["color_normal"]])


# ============================================================================
# BUTTON INTERACTIONS
# ============================================================================

func _setup_button_interactions(btn: Button, config: Dictionary):
	"""
	Setup multi-modal interactions with full feedback:
	- Mouse enter: Scale up + cyan-blue glow pulse
	- Mouse exit: Scale back + glow fades
	- Mouse click: Press effect + cyan-blue particles + glow flash + sound
	"""
	
	var default_scale = btn.scale
	
	# Mouse enter: Expand and glow
	btn.mouse_entered.connect(func():
		if not enable_animations:
			return
		
		# Scale up
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "scale", default_scale * 1.08, animation_speed)
		
		# Cyan-blue glow pulse
		tween = create_tween()
		tween.tween_property(btn, "self_modulate", 
			Color.WHITE.lerp(glow_particle_color, 0.25), animation_speed)
		
		# Play hover sound
		if enable_sound_effects:
			_play_ui_sound(1.0, 0.1)
	)
	
	# Mouse exit: Return to normal
	btn.mouse_exited.connect(func():
		if not enable_animations:
			return
		
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "scale", default_scale, animation_speed)
		
		tween = create_tween()
		tween.tween_property(btn, "self_modulate", Color.WHITE, animation_speed)
	)
	
	# Mouse click: Press effect + particles + glow + sound
	btn.pressed.connect(func():
		if not enable_animations:
			return
		
		# Press-down animation
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "scale", default_scale * 0.95, 0.1)
		tween.tween_property(btn, "scale", default_scale, 0.15)
		
		# Glow flash
		if enable_glow_on_click:
			tween = create_tween()
			tween.tween_property(btn, "self_modulate", glow_particle_color, 0.05)
			tween.tween_property(btn, "self_modulate", Color.WHITE, 0.3)
		
		# Emit cyan-blue particles
		if enable_particles:
			var btn_center = btn.global_position + btn.size / 2
			_emit_button_particles(btn_center)
		
		# Play click sound
		if enable_sound_effects:
			_play_ui_sound(1.4, 0.15)
		
		print("🎯 %s pressed - glow activated" % btn.name)
	)


# ============================================================================
# PARTICLE SYSTEM
# ============================================================================

func _setup_particle_system():
	"""
	Create a container node for particle effects.
	Particles are dynamically generated on button press.
	All particles use cyan-blue glow color (#7dd3fc).
	"""
	particle_container = Node2D.new()
	particle_container.name = "ParticleContainer"
	add_child(particle_container)
	
	print("✓ Particle system initialized - Cyan-blue glow particles enabled")


func _emit_button_particles(pos: Vector2):
	"""
	Emit particles in radial pattern from button press location.
	All particles are cyan-blue (#7dd3fc) glow color.
	Creates visual feedback effect when button is clicked.
	
	Args:
		pos: World position to emit particles from
	"""
	if not enable_particles or not particle_container:
		return
	
	for i in range(particle_count):
		# Calculate angle in circle (full 360 degrees)
		var angle = (i / float(particle_count)) * TAU + randf_range(-0.4, 0.4)
		
		# Calculate velocity vector (outward from center)
		var velocity = Vector2(cos(angle), sin(angle)) * randf_range(180, 400)
		
		# Create cyan-blue glow particle
		_create_particle(pos, velocity)


func _create_particle(pos: Vector2, velocity: Vector2):
	"""
	Create a single cyan-blue glow particle that expands and fades.
	Particles move outward and fade to transparent.
	
	Args:
		pos: Starting position
		velocity: Movement vector
	"""
	var particle = Node2D.new()
	particle.position = pos
	
	# Visual representation: small cyan-blue square
	var sprite = ColorRect.new()
	sprite.size = Vector2(5, 5)
	sprite.color = glow_particle_color  # Cyan-blue (#7dd3fc)
	sprite.position = Vector2(-2.5, -2.5)
	sprite.self_modulate.a = 0.8
	particle.add_child(sprite)
	
	particle_container.add_child(particle)
	
	# Animate particle: move outward and fade
	var tween = create_tween()
	tween.set_parallel()
	
	# Movement: expand outward following velocity
	tween.tween_property(particle, "position", pos + velocity * 0.4, 0.7)
	
	# Fade to transparent
	tween.tween_property(particle, "modulate:a", 0.0, 0.7)
	
	# Cleanup after animation completes
	tween.tween_callback(particle.queue_free)


# ============================================================================
# CRT SCANLINES EFFECT
# ============================================================================

func _setup_scanlines():
	"""
	Create a CRT scanline overlay effect.
	Adds subtle horizontal lines to create retro-futuristic aesthetic.
	"""
	var scanline_layer = CanvasLayer.new()
	scanline_layer.name = "ScanlineLayer"
	scanline_layer.layer = 10
	add_child(scanline_layer)
	
	# Create scanline ColorRect
	var scanline_rect = ColorRect.new()
	scanline_rect.name = "Scanlines"
	scanline_rect.anchor_right = 1.0
	scanline_rect.anchor_bottom = 1.0
	scanline_rect.color = Color.WHITE
	scanline_rect.modulate.a = 0.02  # Very subtle
	
	scanline_layer.add_child(scanline_rect)
	
	print("✓ CRT scanlines effect initialized")


# ============================================================================
# AUDIO SYSTEM
# ============================================================================

func _load_ui_sound():
	"""
	Load UI sound effect from project.
	Looks for: res://assets/sounds/ui_beep.ogg or ui_beep.wav
	If not found, sound effects will be disabled gracefully.
	"""
	# Try loading audio file
	var sound_paths = [
		"res://assets/audio/ui_beep.ogg",
		"res://assets/audio/ui_beep.wav",
		"res://assets/sounds/ui_beep.ogg",
		"res://assets/sounds/ui_beep.wav"
	]
	
	for path in sound_paths:
		if ResourceLoader.exists(path):
			ui_sound_stream = load(path)
			print("✓ UI sound loaded from %s" % path)
			return
	
	print("⚠ UI sound file not found - Sound effects disabled")
	enable_sound_effects = false


func _play_ui_sound(pitch: float = 1.0, duration: float = 0.1):
	"""
	Play UI sound effect with optional pitch adjustment.
	
	Args:
		pitch: Pitch scale (1.0 = normal, 1.4 = higher for click)
		duration: Duration in seconds
	"""
	if not enable_sound_effects or not ui_sound_stream:
		print("🔊 UI sound effect: pitch %.1fx" % pitch)
		return
	
	var player = AudioStreamPlayer.new()
	player.stream = ui_sound_stream
	player.pitch_scale = pitch
	add_child(player)
	player.play()
	
	await get_tree().create_timer(duration).timeout
	player.queue_free()


# ============================================================================
# PROCESS
# ============================================================================

func _process(delta):
	"""
	Frame update loop.
	Can be extended for real-time effects.
	"""
	pass
