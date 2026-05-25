extends CanvasLayer

@export var experience_manager: Node
@onready var progress_bar = $MarginContainer/ProgressBar

var level_label: Label
var score_label: Label
var current_score: int = 0

func _ready():
	progress_bar.value = 0
	experience_manager.experience_updated.connect(on_experience_updated)
	experience_manager.level_up.connect(on_level_up)
	
	# 创建等级标签
	level_label = Label.new()
	level_label.text = "Level: 1"
	level_label.add_theme_font_size_override("font_size", 20)
	$MarginContainer.add_child(level_label)
	
	# 创建分数标签
	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.add_theme_font_size_override("font_size", 20)
	score_label.anchor_top = 0
	score_label.anchor_left = 1
	score_label.anchor_right = 1
	score_label.offset_left = -150
	score_label.offset_top = 10
	add_child(score_label)
	
	GameEvents.experience_vial_collected.connect(on_experience_collected)
	
	print("✅ Experience UI initialized")
	
func on_experience_updated(current_experience: float, target_experience: float):
	var percent = current_experience / target_experience
	progress_bar.value = percent
	
func on_level_up(new_level: int):
	if level_label:
		level_label.text = "Level: %d" % new_level
		print("📈 Level up! Current level: %d" % new_level)

func on_experience_collected(amount: float):
	current_score += int(amount)
	if score_label:
		score_label.text = "Score: %d" % current_score
