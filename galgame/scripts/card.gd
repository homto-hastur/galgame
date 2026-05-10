extends Panel

# ============================================================
#  卡牌 UI 元件（殺戮尖塔風格）
#  支援：懸停浮起放大、拖拽使用、右鍵取消
#  尺寸：120x170
# ============================================================

class_name CardUI

# 卡牌資料
var card_data: Dictionary = {}
var is_playable: bool = false
var is_hovered: bool = false

# 拖拽狀態
var is_dragging: bool = false
var drag_start_pos: Vector2
var original_scale: Vector2 = Vector2.ONE

# 節點參照
@onready var name_label: Label = $Margin/VBox/NameLabel
@onready var cost_label: Label = $Margin/VBox/CostLabel
@onready var resource_cost_label: Label = $Margin/VBox/ResourceCostLabel
@onready var type_label: Label = $Margin/VBox/TypeLabel
@onready var desc_label: Label = $Margin/VBox/DescLabel
@onready var flavor_label: Label = $Margin/VBox/FlavorLabel
@onready var uses_label: Label = $Margin/VBox/UsesLabel
@onready var highlight: ColorRect = $Highlight

# 信號
signal card_used(card_data: Dictionary)
signal card_hovered(index: int, hovered: bool)
signal card_drag_started(card_ui: CardUI)
signal card_drag_ended(card_ui: CardUI, was_used: bool)

var hand_index: int = -1  # 在手牌中的索引


func _ready() -> void:
	# 設定卡牌樣式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 1)
	style.border_color = Color(0, 0, 0, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)
	
	highlight.visible = false
	original_scale = scale


# 初始化卡牌顯示
func setup(data: Dictionary) -> void:
	card_data = data
	
	# 名稱
	name_label.text = data.get("name", "未知卡牌")
	
	# 費用（行動點）
	var cost = data.get("cost", 0)
	cost_label.text = "費用: %d" % cost
	
	# 資源消耗
	var resource_cost = data.get("resource_cost", 0)
	if resource_cost > 0:
		resource_cost_label.text = "資源: %d" % resource_cost
		resource_cost_label.visible = true
	else:
		resource_cost_label.visible = false
	
	# 類型
	var type_name = ""
	match data.get("type", ""):
		"weapon": type_name = "武器"
		"spell": type_name = "法術"
		"item": type_name = "道具"
		"skill": type_name = "技能"
		"event": type_name = "事件"
		_: type_name = data.get("type", "未知")
	type_label.text = type_name
	
	# 根據類型設定顏色標記
	match data.get("type", ""):
		"weapon":
			$TypeColor.color = Color(0.9, 0.3, 0.2, 0.3)  # 紅色系
		"spell":
			$TypeColor.color = Color(0.4, 0.3, 0.8, 0.3)  # 紫色系
		"item":
			$TypeColor.color = Color(0.2, 0.6, 0.3, 0.3)  # 綠色系
		"skill":
			$TypeColor.color = Color(0.3, 0.5, 0.8, 0.3)  # 藍色系
	
	# 效果描述
	desc_label.text = data.get("description", "")
	
	# 風味文字
	var flavor = data.get("flavor", "")
	flavor_label.text = flavor if flavor else ""
	flavor_label.visible = not flavor.is_empty()
	
	# 使用次數
	var uses = data.get("uses", null)
	if uses != null:
		uses_label.text = "使用次數: %d" % uses
		uses_label.visible = true
	else:
		uses_label.visible = false


# 設定是否可使用（高亮）
func set_playable(playable: bool) -> void:
	is_playable = playable
	if playable:
		highlight.visible = true
		highlight.color = Color(1, 1, 0, 0.15)  # 淡黃色高亮
		mouse_filter = MOUSE_FILTER_STOP
	else:
		highlight.visible = false
		mouse_filter = MOUSE_FILTER_IGNORE


# ============================================================
#  懸停效果（殺戮尖塔風格：浮起 + 放大）
# ============================================================

func _on_mouse_entered() -> void:
	if not is_playable or is_dragging:
		return
	is_hovered = true
	card_hovered.emit(hand_index, true)
	
	# 向上浮起 + 放大
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - 35, 0.12)
	tween.parallel().tween_property(self, "scale", original_scale * 1.15, 0.12)
	z_index = 10


func _on_mouse_exited() -> void:
	if not is_hovered or is_dragging:
		return
	is_hovered = false
	card_hovered.emit(hand_index, false)
	
	# 恢復原位
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y + 35, 0.12)
	tween.parallel().tween_property(self, "scale", original_scale, 0.12)
	z_index = 0


# ============================================================
#  拖拽系統
# ============================================================

func _on_gui_input(event: InputEvent) -> void:
	if not is_playable:
		return
	
	# 右鍵取消拖拽
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if is_dragging:
			_cancel_drag()
		return
	
	# 左鍵按下：開始拖拽
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not is_dragging:
			_start_drag()
		elif not event.pressed and is_dragging:
			_end_drag()
	
	# 拖拽中：跟隨滑鼠
	if event is InputEventMouseMotion and is_dragging:
		position += event.relative


# 開始拖拽
func _start_drag() -> void:
	is_dragging = true
	drag_start_pos = position
	
	# 放大 + 陰影效果
	scale = original_scale * 1.3
	z_index = 100
	
	# 通知手牌面板
	card_drag_started.emit(self)


# 結束拖拽（檢查是否落在有效目標上）
func _end_drag() -> void:
	is_dragging = false
	
	# 檢查滑鼠下方是否有有效目標
	var target = _get_target_under_mouse()
	if target != null:
		# 使用卡牌
		card_drag_ended.emit(self, true)
		card_used.emit(card_data)
	else:
		# 回彈到手牌
		card_drag_ended.emit(self, false)
		_return_to_hand()


# 取消拖拽（右鍵）
func _cancel_drag() -> void:
	is_dragging = false
	card_drag_ended.emit(self, false)
	_return_to_hand()


# 回彈動畫
func _return_to_hand() -> void:
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", drag_start_pos, 0.25)
	tween.parallel().tween_property(self, "scale", original_scale, 0.2)
	tween.tween_callback(func():
		z_index = 0
	)


# 檢查滑鼠下方是否有可互動目標
func _get_target_under_mouse() -> Node:
	# 目前簡單檢查：如果拖到地圖區域上方則視為有效
	# 後續可擴展為檢查具體節點/敵人
	var map = get_tree().get_first_node_in_group("map")
	if map and map.get_global_rect().has_point(get_global_mouse_position()):
		return map
	return null


# 使用卡牌動畫（飛向目標）
func play_use_animation(target_pos: Vector2) -> void:
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "global_position", target_pos, 0.3)
	tween.parallel().tween_property(self, "scale", Vector2.ZERO, 0.3)
	tween.tween_callback(func():
		queue_free()
	)
