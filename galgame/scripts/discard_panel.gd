extends Control

# ============================================================
#  棄牌堆檢視面板
#  點擊棄牌堆按鈕後彈出，顯示已結算的卡牌
# ============================================================

class_name DiscardPanel

var card_manager: CardManager = null

# 節點參照
@onready var card_container: GridContainer = $Margin/VBox/ScrollContainer/GridContainer
@onready var count_label: Label = $Margin/VBox/Header/CountLabel
@onready var close_button: Button = $Margin/VBox/Header/CloseButton


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)


# 設定卡牌管理器並刷新顯示
func setup(manager: CardManager) -> void:
	card_manager = manager
	_refresh_display()


# 刷新棄牌堆顯示
func _refresh_display() -> void:
	# 清除舊卡牌
	for child in card_container.get_children():
		child.queue_free()
	
	if card_manager == null:
		return
	
	var cards = card_manager.get_discard_cards()
	count_label.text = "棄牌堆 (%d 張)" % cards.size()
	
	if cards.is_empty():
		var empty_label = Label.new()
		empty_label.text = "棄牌堆為空"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.theme_override_colors.font_color = Color(0.5, 0.5, 0.5, 1)
		empty_label.theme_override_font_sizes.font_size = 16
		card_container.add_child(empty_label)
		return
	
	# 為每張棄牌建立小型卡牌顯示
	for card_data in cards:
		var card_ui = _create_discard_card_ui(card_data)
		card_container.add_child(card_ui)


# 建立棄牌堆卡牌 UI（小型化，不可互動）
func _create_discard_card_ui(data: Dictionary) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(140, 100)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.95, 0.95, 1)
	style.border_color = Color(0.3, 0.3, 0.3, 1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	
	# 名稱
	var name_label = Label.new()
	name_label.text = data.get("name", "未知")
	name_label.theme_override_colors.font_color = Color(0, 0, 0, 1)
	name_label.theme_override_font_sizes.font_size = 14
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)
	
	# 類型
	var type_name = ""
	match data.get("type", ""):
		"weapon": type_name = "武器"
		"spell": type_name = "法術"
		"item": type_name = "道具"
		"skill": type_name = "技能"
		"event": type_name = "事件"
		_: type_name = data.get("type", "未知")
	
	var type_label = Label.new()
	type_label.text = type_name
	type_label.theme_override_colors.font_color = Color(0.4, 0.4, 0.4, 1)
	type_label.theme_override_font_sizes.font_size = 11
	vbox.add_child(type_label)
	
	# 描述
	var desc = data.get("description", "")
	if not desc.is_empty():
		var desc_label = Label.new()
		desc_label.text = desc
		desc_label.theme_override_colors.font_color = Color(0.2, 0.2, 0.2, 1)
		desc_label.theme_override_font_sizes.font_size = 11
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.max_lines_visible = 2
		vbox.add_child(desc_label)
	
	return panel


# 關閉按鈕
func _on_close_pressed() -> void:
	queue_free()
