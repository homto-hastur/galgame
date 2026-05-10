extends Control

# ============================================================
#  手牌面板（殺戮尖塔風格扇形佈局）
#  卡牌在底部扇形排列，支援懸停放大、拖拽使用
# ============================================================

class_name HandPanel

var card_manager: CardManager = null
var available_actions: int = 0
var available_resources: int = 0

# 扇形佈局參數
const CARD_WIDTH: float = 120.0
const CARD_HEIGHT: float = 170.0
const FAN_ANGLE_DEG: float = 20.0       # 單側最大角度（更小，減少扇形弧度）
const FAN_SPREAD: float = 400.0         # 水平展開寬度
const BASE_Y_OFFSET: float = 100.0      # 底部往上偏移（數值越小越靠下）
const CARD_OVERLAP: float = 0.65        # 卡牌重疊比例（0.65 = 每張牌覆蓋前一張的65%寬度）

# 節點參照
@onready var deck_label: Label = $DeckLabel
@onready var discard_button: Button = $DiscardButton

# 卡牌列表
var card_uis: Array[CardUI] = []
var _original_positions: Array[Vector2] = []  # 每張卡牌的原始位置

# 信號
signal card_used(card_data: Dictionary)


func _ready() -> void:
	pass


# 設定卡牌管理器
func set_card_manager(manager: CardManager) -> void:
	card_manager = manager
	card_manager.hand_updated.connect(_on_hand_updated)
	card_manager.deck_updated.connect(_on_deck_updated)
	card_manager.discard_updated.connect(_on_discard_updated)
	
	# 初始化顯示
	_refresh_hand_display()
	deck_label.text = "牌庫: %d" % card_manager.get_deck_count()
	discard_button.text = "棄牌: %d" % card_manager.get_discard_count()
	
	# 連接棄牌堆按鈕
	discard_button.pressed.connect(_on_discard_button_pressed)


# 更新可用行動點數
func set_available_actions(actions: int) -> void:
	available_actions = actions
	_refresh_playable_state()

# 更新可用資源
func set_available_resources(resources: int) -> void:
	available_resources = resources
	_refresh_playable_state()


# 手牌更新回調
func _on_hand_updated(_hand_cards: Array) -> void:
	_refresh_hand_display()
	# 手牌更新時也更新牌庫/棄牌堆位置
	_update_pile_labels_position()



# 牌組更新回調
func _on_deck_updated(deck_count: int) -> void:
	deck_label.text = "牌庫: %d" % deck_count

# 棄牌堆更新回調
func _on_discard_updated(discard_count: int) -> void:
	discard_button.text = "棄牌: %d" % discard_count


# ============================================================
#  扇形佈局演算法
# ============================================================

# 計算扇形位置（含重疊效果）
func _calculate_fan_positions(card_count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if card_count <= 0:
		return positions
	
	var screen_width: float = get_viewport_rect().size.x
	var base_y: float = get_viewport_rect().size.y - BASE_Y_OFFSET
	var center_x: float = screen_width / 2.0
	var max_angle: float = deg_to_rad(FAN_ANGLE_DEG)
	
	if card_count == 1:
		positions.append(Vector2(center_x - CARD_WIDTH / 2.0, base_y))
		return positions
	
	# 計算重疊佈局
	# 每張牌的顯示寬度 = CARD_WIDTH * (1 - CARD_OVERLAP)
	var visible_width: float = CARD_WIDTH * (1.0 - CARD_OVERLAP)
	# 總寬度 = 第一張牌左邊緣到最後一張牌右邊緣
	var total_width: float = visible_width * (card_count - 1) + CARD_WIDTH
	# 起始 X 位置（置中）
	var start_x: float = center_x - total_width / 2.0
	
	for i in range(card_count):
		# 水平位置：從左到右，每張牌重疊
		var x: float = start_x + i * visible_width
		
		# 垂直位置：中間高兩邊低（弧形）
		var t: float = float(i) / float(card_count - 1)  # 0.0 ~ 1.0
		var angle: float = lerp(-max_angle, max_angle, t)
		var y: float = base_y - abs(sin(angle)) * 40.0
		
		positions.append(Vector2(x, y))
	
	return positions


# 計算卡牌縮放比例
func _calculate_card_scale(card_count: int) -> float:
	if card_count <= 3:
		return 1.0
	elif card_count <= 6:
		return 0.9
	elif card_count <= 10:
		return 0.8
	else:
		return 0.7


# ============================================================
#  刷新手牌顯示
# ============================================================

func _refresh_hand_display() -> void:
	# 清除舊卡牌
	for card in card_uis:
		card.queue_free()
	card_uis.clear()
	_original_positions.clear()
	
	if card_manager == null:
		return
	
	var hand = card_manager.get_hand()
	
	# 更新牌庫/棄牌堆位置（與手牌同一水平高度）
	_update_pile_labels_position()
	
	if hand.is_empty():
		return
	
	var card_count = hand.size()
	var positions = _calculate_fan_positions(card_count)
	var scale_val = _calculate_card_scale(card_count)
	
	# 為每張手牌建立卡牌 UI
	for i in range(card_count):
		var card_scene = preload("res://scenes/Card.tscn")
		var card_ui = card_scene.instantiate() as CardUI
		card_ui.hand_index = i
		card_ui.scale = Vector2(scale_val, scale_val)
		card_ui.original_scale = Vector2(scale_val, scale_val)
		
		# 設定位置
		card_ui.position = positions[i]
		
		# 連接信號
		card_ui.card_used.connect(_on_card_used.bind(i))
		card_ui.card_hovered.connect(_on_card_hovered)
		card_ui.card_drag_started.connect(_on_card_drag_started)
		card_ui.card_drag_ended.connect(_on_card_drag_ended)
		
		add_child(card_ui)
		# 先加入場景樹（確保 @onready 變數初始化），再設定卡牌資料
		card_ui.setup(hand[i])
		card_uis.append(card_ui)
		_original_positions.append(positions[i])
	
	# 刷新可玩狀態
	_refresh_playable_state()


# 更新牌庫/棄牌堆標籤位置（與手牌同一水平高度）
func _update_pile_labels_position() -> void:
	var base_y: float = get_viewport_rect().size.y - BASE_Y_OFFSET
	# 牌庫標籤在左側，與手牌同一水平
	deck_label.position = Vector2(deck_label.position.x, base_y)
	# 棄牌堆按鈕在右側，與手牌同一水平
	discard_button.position = Vector2(discard_button.position.x, base_y)


# 棄牌堆按鈕點擊：打開棄牌堆檢視面板
func _on_discard_button_pressed() -> void:
	if card_manager == null:
		return
	
	var discard_scene = preload("res://scenes/DiscardPanel.tscn")
	var discard_panel = discard_scene.instantiate() as DiscardPanel
	discard_panel.setup(card_manager)
	add_child(discard_panel)


# 刷新卡牌是否可使用
func _refresh_playable_state() -> void:
	for i in range(card_uis.size()):
		var card_ui = card_uis[i]
		if card_ui and card_manager:
			var can_play = card_manager.can_play_card(i, available_actions, available_resources)
			card_ui.set_playable(can_play)


# ============================================================
#  懸停推開效果（殺戮尖塔風格）
# ============================================================

func _on_card_hovered(index: int, hovered: bool) -> void:
	if hovered:
		# 懸停：相鄰卡牌向兩側推開
		_push_adjacent_cards(index, 25.0)
	else:
		# 取消懸停：恢復所有卡牌位置
		_restore_all_positions()


# 推開相鄰卡牌
func _push_adjacent_cards(hover_index: int, push_amount: float) -> void:
	for i in range(card_uis.size()):
		if i == hover_index:
			continue
		
		var card_ui = card_uis[i]
		var original_pos = _original_positions[i]
		var offset: float = 0.0
		
		# 左側卡牌向左推，右側卡牌向右推
		if i < hover_index:
			offset = -push_amount * (1.0 - float(hover_index - i) / float(hover_index + 1))
		else:
			offset = push_amount * (1.0 - float(i - hover_index) / float(card_uis.size() - hover_index))
		
		var target_pos = Vector2(original_pos.x + offset, original_pos.y)
		
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(card_ui, "position", target_pos, 0.12)


# 恢復所有卡牌到原始位置
func _restore_all_positions() -> void:
	for i in range(card_uis.size()):
		var card_ui = card_uis[i]
		var original_pos = _original_positions[i]
		
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(card_ui, "position", original_pos, 0.12)


# ============================================================
#  拖拽處理
# ============================================================

func _on_card_drag_started(card_ui: CardUI) -> void:
	# 拖拽開始時，將卡牌移到最上層
	card_ui.z_index = 100


func _on_card_drag_ended(_card_ui: CardUI, was_used: bool) -> void:
	if not was_used:
		# 如果取消使用，恢復所有卡牌位置
		_restore_all_positions()



# ============================================================
#  卡牌使用
# ============================================================

func _on_card_used(card_data: Dictionary, index: int) -> void:
	if card_manager == null:
		return
	
	# 使用卡牌
	if card_manager.use_card(index):
		card_used.emit(card_data)
