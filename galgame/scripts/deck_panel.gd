extends Control

# ============================================================
#  牌庫檢視面板
#  參考棄牌堆面板風格：黑色半透明背景 + 中央白色面板
#  展示牌庫中剩餘的卡牌（僅供檢視，非抽牌順序）
# ============================================================

class_name DeckPanel

var card_manager: CardManager = null
var _pending_setup: bool = false

# 節點參照
@onready var card_container: GridContainer = $Panel/Margin/VBox/ScrollContainer/GridContainer
@onready var count_label: Label = $Panel/Margin/VBox/Header/CountLabel
@onready var close_button: Button = $Panel/Margin/VBox/Header/CloseButton


func _ready() -> void:
	add_to_group("card_panel")
	close_button.pressed.connect(_on_close_pressed)
	# 點擊背景關閉
	$Background.gui_input.connect(_on_background_gui_input)
	if _pending_setup:
		_refresh_display()


# 點擊背景關閉
func _on_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		queue_free()


# 設定卡牌管理器並刷新顯示
func setup(manager: CardManager) -> void:
	card_manager = manager
	if not is_node_ready():
		_pending_setup = true
		return
	_refresh_display()


# 刷新牌庫顯示
func _refresh_display() -> void:
	# 清除舊卡牌
	for child in card_container.get_children():
		child.queue_free()
	
	if card_manager == null:
		return
	
	var cards = card_manager.get_deck_cards()
	count_label.text = "牌庫 (%d 張)" % cards.size()
	
	if cards.is_empty():
		var empty_label = Label.new()
		empty_label.text = "牌庫為空"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		empty_label.add_theme_font_size_override("font_size", 16)
		card_container.add_child(empty_label)
		return
	
	# 使用 Card.tscn 展示每張牌庫卡牌（與手牌顯示一致）
	var card_scene = preload("res://scenes/Card.tscn")
	for card_data in cards:
		var card_ui = card_scene.instantiate() as CardUI
		card_ui.scale = Vector2(0.85, 0.85)
		card_container.add_child(card_ui)
		# 先加入場景樹（確保 @onready 變數初始化），再設定卡牌資料
		card_ui.mouse_filter = MOUSE_FILTER_IGNORE  # 不可互動
		card_ui.setup(card_data)


# 關閉按鈕
func _on_close_pressed() -> void:
	queue_free()
