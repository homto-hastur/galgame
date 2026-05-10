extends Control


# 地點資料（參考 Arkham Horror 地點系統）
var location_data := {
	0: {
		"name": "大門",
		"desc": "巨大的鐵門矗立眼前，鏽跡斑斑的門環訴說著久遠的故事。這裡是地牢唯一的出口，也是通往各處的必經之路。",
		"shroud": 0,
		"clues": 0,
		"connections": [1],
		"locked": false
	},
	1: {
		"name": "走廊",
		"desc": "陰暗狹長的走道，牆上的火把早已熄滅。腳步聲在空蕩的廊道中迴盪，似乎有什麼東西在暗處注視著你。",
		"shroud": 2,
		"clues": 1,
		"connections": [0, 2],
		"locked": true
	},
	2: {
		"name": "大廳",
		"desc": "曾經奢華的大廳如今只剩殘破的掛毯和碎裂的雕像。月光從高處的窗戶灑落，照亮了滿地的塵埃。",
		"shroud": 3,
		"clues": 2,
		"connections": [1, 4, 5],
		"locked": true
	},
	3: {
		"name": "圖書館",
		"desc": "書架上塞滿了泛黃的書卷，空氣中瀰漫著古老紙張的氣味。某本書的書頁間似乎夾著什麼重要的線索。",
		"shroud": 4,
		"clues": 3,
		"connections": [5],
		"locked": true
	},
	4: {
		"name": "寶物庫",
		"desc": "金幣和珠寶散落一地，在昏暗的光線下閃爍著誘人的光芒。但寶物之中似乎隱藏著致命的陷阱。",
		"shroud": 3,
		"clues": 2,
		"connections": [2, 5],
		"locked": true
	},
	5: {
		"name": "BOSS",
		"desc": "一股令人窒息的壓迫感籠罩著這個房間。黑暗中，一個巨大的身影緩緩轉過身來——最終的挑戰就在眼前。",
		"shroud": 5,
		"clues": 4,
		"connections": [2, 4, 3],
		"locked": true
	}
}

var current_node_id: int = 0

# 角色狀態（參考 Arkham Horror 數值）
var player_hp: int = 6
var player_max_hp: int = 6
var player_sanity: int = 5
var player_max_sanity: int = 5

# 能力值（參考 Arkham Horror LCG 調查員數值，範圍 1~5）
var player_willpower: int = 3     # 意志力 WP - 意志、決心
var player_intellect: int = 4     # 智力 INT - 調查、解謎
var player_combat: int = 3        # 戰鬥 COMBAT - 近戰、攻擊
var player_agility: int = 3       # 敏捷 AGI - 閃避、潛行

# 裝備列表
var player_equipment: Array[String] = []

# 資源（參考 Arkham Horror 資源系統，用於打出卡牌）
var player_resources: int = 5
var player_max_resources: int = 99

# 行動次數（參考 Arkham Horror，每回合 3 次行動）
var player_actions: int = 3
var player_max_actions: int = 3

var zoom_level: float = 1.0
var zoom_levels: Array = [0.5, 0.6, 0.7, 0.8, 0.85, 0.9, 0.95, 1.0, 1.2, 1.5, 2.0]
var min_zoom_index: int = 0
var max_zoom_index: int = 10
var zoom_index: int = 7  # 對應 1.0
var dragging: bool = false
var drag_start: Vector2
var node_positions := []
var _node_buttons: Dictionary = {}  # node_id -> Button，儲存所有地點按鈕

# 卡牌拖拽鎖定（拖拽卡牌時禁止地圖平移/縮放）
var card_dragging: bool = false

@onready var map_content: Control = $MapContent
@onready var bg: TextureRect = $MapContent/Background
@onready var nodes_container: Control = $MapContent/NodesContainer
@onready var arrows_container: Control = $MapContent/ArrowsContainer
@onready var player_piece: Control = $MapContent/PlayerPiece
@onready var player_sprite: Sprite2D = $MapContent/PlayerPiece/Sprite
@onready var tooltip: Panel = $MapContent/Tooltip
@onready var tooltip_label: Label = $MapContent/Tooltip/Label
@onready var dialogue_overlay: ColorRect = $DialogueOverlay
@onready var dialogue_speaker: Label = $DialogueOverlay/DialoguePanel/Margin/VBox/Speaker
@onready var dialogue_content: RichTextLabel = $DialogueOverlay/DialoguePanel/Margin/VBox/Content
@onready var draw_card_btn: Button = $ActionPanel/DrawCardBtn
@onready var gain_resource_btn: Button = $ActionPanel/GainResourceBtn
@onready var deck_empty_overlay: ColorRect = $DeckEmptyOverlay

# 卡牌系統
@onready var card_manager = $CardManager
@onready var hand_panel = $HandPanel



func _ready() -> void:
	# 加入地圖群組（供卡牌拖拽目標檢測）
	add_to_group("map")
	
	# 初始化精靈圖動畫系統
	_init_sprite_animation()

	
	# 進入地圖時顯示開場對話
	_show_entry_dialogue()
	bg.texture = preload("res://assets/backgrounds/捲軸.png")

	bg.size = Vector2(2400, 1800)
	# 計算縮放邊界
	var max_z = 2.0
	var min_z = maxf(size.x / 2400.0, size.y / 1800.0)
	max_zoom_index = zoom_levels.size() - 1
	for i in range(zoom_levels.size()):
		if zoom_levels[i] < min_z:
			min_zoom_index = i
		if zoom_levels[i] > max_z:
			max_zoom_index = i - 1
			break
	zoom_index = clampi(zoom_index, min_zoom_index, max_zoom_index)
	zoom_level = zoom_levels[zoom_index]
	_init_map_nodes()
	map_content.scale = Vector2(zoom_level, zoom_level)
	
	# 視野以玩家為中心
	_center_on_player()
	
	_clamp_map()
	
	# 初始化行動次數顯示
	_update_action_crosses()
	
	# 初始化資源顯示
	_update_resource_display()
	
	# 初始化卡牌系統
	_init_card_system()
	
	# 連接抽卡和獲取資源按鈕
	draw_card_btn.pressed.connect(_on_draw_card_pressed)
	gain_resource_btn.pressed.connect(_on_gain_resource_pressed)


# 初始化卡牌系統
func _init_card_system() -> void:
	# 初始化牌組
	card_manager.init_default_deck()
	
	# 初始抽 5 張手牌
	card_manager.draw_cards(5)
	
	# 設定手牌面板
	hand_panel.set_card_manager(card_manager)
	hand_panel.set_available_actions(player_actions)
	hand_panel.set_available_resources(player_resources)
	
	# 連接卡牌使用信號
	hand_panel.card_used.connect(_on_card_used_from_hand)
	
	# 連接卡牌棄牌信號
	hand_panel.card_discarded.connect(_on_card_discarded_from_hand)
	
	# 連接裝備變更信號（更新裝備顯示）
	card_manager.equipment_changed.connect(_on_equipment_changed)
	
	# 連接牌庫抽空信號
	card_manager.deck_empty.connect(_on_deck_empty)
	
	# 連接卡牌拖拽信號（拖拽時鎖定地圖平移/縮放）
	hand_panel.card_drag_started.connect(_on_card_drag_started)
	hand_panel.card_drag_ended.connect(_on_card_drag_ended)


# 卡牌拖拽開始：鎖定地圖平移和縮放
func _on_card_drag_started() -> void:
	card_dragging = true


# 卡牌拖拽結束：解除地圖鎖定，並重置地圖拖拽狀態
func _on_card_drag_ended() -> void:
	card_dragging = false
	dragging = false


# 裝備變更時更新裝備顯示
func _on_equipment_changed(_slot: String, _card_data) -> void:
	_update_equipment_display()


# 牌庫抽空時剩餘要補抽的牌數
var _deck_empty_remaining: int = 0


# 牌庫抽空時顯示通知界面
func _on_deck_empty(remaining_count: int) -> void:
	# 記錄剩餘要補抽的牌數
	_deck_empty_remaining = remaining_count
	
	# 顯示牌庫抽空通知（參考場景1存檔界面風格，白色面板+黑色邊框，螢幕中央）
	deck_empty_overlay.visible = true
	deck_empty_overlay.modulate = Color(1, 1, 1, 0)
	
	# 連接按鈕事件
	var btn_hp = deck_empty_overlay.get_node("Panel/Margin/VBox/BtnHP") as Button
	var btn_san = deck_empty_overlay.get_node("Panel/Margin/VBox/BtnSan") as Button
	
	# 先斷開舊連接避免重複
	if btn_hp.pressed.is_connected(_on_deck_empty_choose_hp):
		btn_hp.pressed.disconnect(_on_deck_empty_choose_hp)
	if btn_san.pressed.is_connected(_on_deck_empty_choose_san):
		btn_san.pressed.disconnect(_on_deck_empty_choose_san)
	
	btn_hp.pressed.connect(_on_deck_empty_choose_hp)
	btn_san.pressed.connect(_on_deck_empty_choose_san)
	
	# 淡入動畫
	var tween = create_tween()
	tween.tween_property(deck_empty_overlay, "modulate", Color(1, 1, 1, 1), 0.3)


# 選擇扣除 HP
func _on_deck_empty_choose_hp() -> void:
	deck_empty_overlay.visible = false
	# 扣除 1 點生命值
	damage_player(1, 0)
	# 將棄牌堆重新洗入牌庫
	card_manager.reshuffle_discard_into_deck()
	# 補發原本要抽的牌
	if _deck_empty_remaining > 0:
		card_manager.draw_cards(_deck_empty_remaining)
		print("牌庫抽空懲罰：扣除 1 HP，棄牌堆已重新洗入牌庫，補發 %d 張牌" % _deck_empty_remaining)
	else:
		print("牌庫抽空懲罰：扣除 1 HP，棄牌堆已重新洗入牌庫")


# 選擇扣除 SAN
func _on_deck_empty_choose_san() -> void:
	deck_empty_overlay.visible = false
	# 扣除 1 點理智值
	damage_player(0, 1)
	# 將棄牌堆重新洗入牌庫
	card_manager.reshuffle_discard_into_deck()
	# 補發原本要抽的牌
	if _deck_empty_remaining > 0:
		card_manager.draw_cards(_deck_empty_remaining)
		print("牌庫抽空懲罰：扣除 1 SAN，棄牌堆已重新洗入牌庫，補發 %d 張牌" % _deck_empty_remaining)
	else:
		print("牌庫抽空懲罰：扣除 1 SAN，棄牌堆已重新洗入牌庫")


# 處理卡牌棄牌

func _on_card_discarded_from_hand(card_data: Dictionary) -> void:
	# 棄牌：從手牌移除並加入棄牌堆
	var card_id = card_data.get("id", "")
	if not card_id.is_empty():
		var actual_index = -1
		for i in range(card_manager.hand.size()):
			if card_manager.hand[i].get("id", "") == card_id:
				actual_index = i
				break
		
		if actual_index >= 0:
			card_manager.hand.remove_at(actual_index)
			card_manager.discard_pile.append(card_id)
			card_manager.hand_updated.emit(card_manager.hand)
			card_manager.discard_updated.emit(card_manager.discard_pile.size())
			print("棄牌: %s" % card_data.get("name", ""))
	
	# 棄牌後檢查手牌是否仍超過上限
	if card_manager.hand.size() > card_manager.MAX_HAND_SIZE:
		print("手牌仍超過 %d 張，請繼續棄牌！" % card_manager.MAX_HAND_SIZE)
		_show_hand_full_warning()
	else:
		# 手牌已低於上限，隱藏警告
		print("手牌已低於上限（%d/%d）" % [card_manager.hand.size(), card_manager.MAX_HAND_SIZE])


# 處理卡牌使用
func _on_card_used_from_hand(card_data: Dictionary) -> void:
	var action_cost = card_data.get("cost", 0)
	var resource_cost = card_data.get("resource_cost", 0)
	
	# 檢查是否有足夠行動點
	if player_actions < action_cost:
		print("行動點不足，無法使用卡牌！")
		return
	
	# 檢查是否有足夠資源
	if player_resources < resource_cost:
		print("資源不足，無法使用卡牌！（需要 %d，目前 %d）" % [resource_cost, player_resources])
		return
	
	# 消耗資源
	player_resources -= resource_cost
	_update_resource_display()
	print("消耗 %d 資源，剩餘: %d" % [resource_cost, player_resources])
	
	# 消耗行動點
	for i in range(action_cost):
		use_action()
	
	# 執行卡牌效果
	_apply_card_effect(card_data)
	
	# 從手牌中移除卡牌（裝備類卡牌會裝備到對應插槽）
	# 放在最後執行，避免 card_manager.use_card 觸發 hand_updated → _refresh_hand_display
	# 導致正在處理的 card_ui 被提前釋放
	var card_id = card_data.get("id", "")
	if not card_id.is_empty():
		var actual_index = -1
		for i in range(card_manager.hand.size()):
			if card_manager.hand[i].get("id", "") == card_id:
				actual_index = i
				break
		if actual_index >= 0:
			card_manager.use_card(actual_index)
	
	# 更新手牌面板的行動點和資源顯示
	hand_panel.set_available_actions(player_actions)
	hand_panel.set_available_resources(player_resources)


# 執行卡牌效果
func _apply_card_effect(card_data: Dictionary) -> void:
	var effect = card_data.get("effect", {})
	var kind = effect.get("kind", "")
	var value = effect.get("value", 0)
	
	match kind:
		"heal_hp":
			heal_player(value, 0)
			print("使用 %s，恢復 %d HP" % [card_data.get("name", ""), value])
		
		"heal_sanity":
			heal_player(0, value)
			print("使用 %s，恢復 %d SAN" % [card_data.get("name", ""), value])
		
		"combat_buff":
			var _dmg = effect.get("damage", 0)
			player_combat += value

			print("使用 %s，戰鬥+%d，持續本回合" % [card_data.get("name", ""), value])
			# 如果是裝備，更新裝備列表顯示
			if card_data.get("slot", null) != null:
				_update_equipment_display()
		
		"defense_buff":
			print("使用 %s，防禦+%d" % [card_data.get("name", ""), value])
			if card_data.get("slot", null) != null:
				_update_equipment_display()
		
		"investigate_buff":
			player_intellect += value
			print("使用 %s，智力+%d" % [card_data.get("name", ""), value])
			if card_data.get("slot", null) != null:
				_update_equipment_display()
		
		"intellect_buff":
			player_intellect += value
			print("使用 %s，智力+%d，持續本回合" % [card_data.get("name", ""), value])
		
		"agility_buff":
			player_agility += value
			print("使用 %s，敏捷+%d，持續本回合" % [card_data.get("name", ""), value])
		
		"damage":
			print("使用 %s，造成 %d 點傷害" % [card_data.get("name", ""), value])
			# 傷害效果在戰鬥系統中處理
		
		"reduce_shroud":
			var current_shroud = location_data[current_node_id]["shroud"]
			location_data[current_node_id]["shroud"] = maxi(0, current_shroud - value)
			print("使用 %s，迷霧值降低 %d（目前: %d）" % [card_data.get("name", ""), value, location_data[current_node_id]["shroud"]])
		
		"shield":
			print("使用 %s，獲得護盾" % [card_data.get("name", "")])
		
		"evade":
			print("使用 %s，閃避攻擊" % [card_data.get("name", "")])
		
		"unlock":
			print("使用 %s，嘗試解鎖" % [card_data.get("name", "")])
			# 解鎖邏輯在互動時處理
	
	# 更新狀態面板
	_update_info_panel()


# 更新裝備顯示
func _update_equipment_display() -> void:
	var equip_list = $InfoPanel/Margin/VBox/EquipList
	if not equip_list:
		return
	
	var equipped_names: Array[String] = []
	if card_manager.equipped["hand"] != null:
		equipped_names.append("手: " + card_manager.equipped["hand"].get("name", ""))
	if card_manager.equipped["accessory"] != null:
		equipped_names.append("飾: " + card_manager.equipped["accessory"].get("name", ""))
	
	if equipped_names.is_empty():
		equip_list.text = "無"
	else:
		equip_list.text = "\n".join(equipped_names)


# 更新資訊面板
func _update_info_panel() -> void:
	var hp_value = $InfoPanel/Margin/VBox/HPBar/HPValue as Label
	var san_value = $InfoPanel/Margin/VBox/SanBar/SanValue as Label
	var hp_progress = $InfoPanel/Margin/VBox/HPBar/HPProgress as ProgressBar
	var san_progress = $InfoPanel/Margin/VBox/SanBar/SanProgress as ProgressBar
	
	if hp_value:
		hp_value.text = "%d/%d" % [player_hp, player_max_hp]
	if san_value:
		san_value.text = "%d/%d" % [player_sanity, player_max_sanity]
	if hp_progress:
		hp_progress.value = player_hp
		hp_progress.max_value = player_max_hp
	if san_progress:
		san_progress.value = player_sanity
		san_progress.max_value = player_max_sanity


# 更新資源顯示
func _update_resource_display() -> void:
	var resource_label = $ActionPanel/ResourceLabel as Label
	if resource_label:
		resource_label.text = "資源: %d/%d" % [player_resources, player_max_resources]


func _init_map_nodes() -> void:
	# 地圖尺寸（2400x1800）
	
	# 地點位置（比例）
	node_positions = [
		Vector2(0.5, 0.5),    # 大門（中央）
		Vector2(0.32, 0.35),  # 走廊（靠近大門）
		Vector2(0.68, 0.35),  # 大廳（靠近大門）
		Vector2(0.29, 0.59),  # 圖書館（靠近大門）
		Vector2(0.71, 0.59),  # 寶物庫（靠近大門）
		Vector2(0.5, 0.71),   # BOSS（靠近大門）
	]
	
	for id in location_data.keys():
		var data = location_data[id]
		var pos = node_positions[id]
		
		# 地點按鈕 - 使用地圖實際尺寸定位
		var btn := Button.new()
		btn.text = data["name"]
		btn.position = Vector2(pos.x * 2400.0 - 60, pos.y * 1800.0 - 30)
		btn.size = Vector2(120, 60)
		btn.pressed.connect(_on_node_pressed.bind(id))
		btn.mouse_entered.connect(_on_btn_hover.bind(id, btn))
		btn.mouse_exited.connect(_on_btn_unhover)
		
		# 已鎖定的地點顯示迷霧值
		if data["locked"]:
			btn.text += "\n[迷霧:%d]" % data["shroud"]
		else:
			btn.text += "\n[線索:%d]" % data["clues"]
		
		nodes_container.add_child(btn)
		_node_buttons[id] = btn
	
	# 初始化節點可見性：只顯示起點（大門）和與起點相鄰的節點
	_update_node_visibility()
	
	# 玩家標記（在大門位置）
	player_piece.position = Vector2(
		node_positions[0].x * 2400.0 - 64,
		node_positions[0].y * 1800.0 - 64
	)
	
	# 在玩家棋子上建立血條和理智條
	_init_player_status_bars()
	
	# 繪製連接箭頭
	_draw_arrows()


func _on_node_pressed(node_id: int) -> void:
	var target_name = location_data[node_id]["name"]
	
	# 檢查是否為相鄰地點
	var current_connections = location_data[current_node_id]["connections"]
	if not node_id in current_connections:
		print("無法前往 %s：不是相鄰地點" % target_name)
		return
	
	# 檢查是否有足夠行動次數
	if player_actions <= 0:
		print("無法移動：沒有剩餘行動次數！")
		return
	
	print("前往節點: ", node_id, " - ", target_name)
	
	# 計算移動方向並播放行走動畫
	var move_dir = _get_move_dir(current_node_id, node_id)
	_start_walk_animation(move_dir)
	
	# 磁吸效果：棋子平滑吸附到目標地點
	var target_pos = Vector2(
		node_positions[node_id].x * 2400.0 - 64,
		node_positions[node_id].y * 1800.0 - 64
	)
	
	var tween = create_tween()
	tween.tween_property(player_piece, "position", target_pos, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		_stop_walk_animation()
	)
	
	# 更新目前位置
	current_node_id = node_id
	
	# 更新節點可見性：只顯示新位置的相鄰節點
	_update_node_visibility()
	
	# 消耗一次行動
	use_action()


func _on_btn_hover(id: int, btn: Button) -> void:
	var data = location_data[id]
	tooltip_label.text = "%s\n%s" % [data["name"], data["desc"]]
	tooltip.position = Vector2(btn.position.x, btn.position.y + btn.size.y + 8)
	tooltip.visible = true
	
	# 檢查是否為相鄰地點且有行動次數 → 啟動十字架閃爍提示
	var current_connections = location_data[current_node_id]["connections"]
	if id in current_connections and player_actions > 0:
		_start_crosses_blink()


func _on_btn_unhover() -> void:
	tooltip.visible = false
	_stop_crosses_blink()


func _input(event: InputEvent) -> void:
	# 對話框開啟時，點擊關閉
	if _is_dialogue_open and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_close_dialogue()
		return
	
	# 牌庫/棄牌堆面板開啟時，鎖定地圖平移和縮放
	if _is_panel_open():
		return
	
	# 拖拽卡牌時，鎖定地圖平移和縮放
	if card_dragging:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_start = event.position
			else:
				dragging = false
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			var old_z = zoom_level
			zoom_index = clampi(zoom_index + 1, min_zoom_index, max_zoom_index)
			zoom_level = zoom_levels[zoom_index]
			_apply_zoom(event.position, old_z)
		
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var old_z = zoom_level
			zoom_index = clampi(zoom_index - 1, min_zoom_index, max_zoom_index)
			zoom_level = zoom_levels[zoom_index]
			_apply_zoom(event.position, old_z)
	
	if dragging and event is InputEventMouseMotion:
		var delta = event.position - drag_start
		map_content.position.x += delta.x
		map_content.position.y += delta.y
		_clamp_map()
		drag_start = event.position


# 檢查是否有牌庫/棄牌堆面板開啟（鎖定地圖操作）
func _is_panel_open() -> bool:
	return get_tree().get_nodes_in_group("card_panel").size() > 0

func _apply_zoom(mouse_pos: Vector2, old_zoom: float) -> void:
	var mouse_in_map = (mouse_pos - map_content.position) / old_zoom
	
	map_content.scale = Vector2(zoom_level, zoom_level)
	bg.size = Vector2(2400, 1800)
	
	map_content.position = mouse_pos - mouse_in_map * zoom_level
	_clamp_map()


# 將視野中心對齊到玩家位置
func _center_on_player() -> void:
	var player_world_pos = Vector2(
		node_positions[0].x * 2400.0,
		node_positions[0].y * 1800.0
	)
	# 計算偏移：讓玩家位置在螢幕中心
	map_content.position = Vector2(
		size.x / 2.0 - player_world_pos.x * zoom_level,
		size.y / 2.0 - player_world_pos.y * zoom_level
	)


func _clamp_map() -> void:
	var map_w = 2400.0 * zoom_level
	var map_h = 1800.0 * zoom_level
	var max_x = 0.0
	var min_x = size.x - map_w
	var max_y = 0.0
	var min_y = size.y - map_h
	
	if map_w <= size.x:
		map_content.position.x = (size.x - map_w) / 2
	else:
		map_content.position.x = clampf(map_content.position.x, min_x, max_x)
	
	if map_h <= size.y:
		map_content.position.y = (size.y - map_h) / 2
	else:
		map_content.position.y = clampf(map_content.position.y, min_y, max_y)


# ============================================================
#  節點可見性控制：只顯示當前地點的相鄰節點
# ============================================================

func _update_node_visibility() -> void:
	# 取得當前地點的相鄰節點列表
	var current_connections = location_data[current_node_id]["connections"]
	
	for id in _node_buttons.keys():
		var btn = _node_buttons[id] as Button
		if not btn:
			continue
		
		# 當前地點永遠顯示
		if id == current_node_id:
			btn.visible = true
			continue
		
		# 與當前地點相鄰的節點顯示
		if id in current_connections:
			btn.visible = true
		else:
			btn.visible = false
	
	# 重新繪製箭頭，只保留與當前節點相鄰的連接線
	_draw_arrows()


# ============================================================
#  繪製連接箭頭（使用 Godot 內建繪圖）
# ============================================================

func _draw_arrows() -> void:
	# 清除舊箭頭
	for child in arrows_container.get_children():
		child.queue_free()
	
	# 建立 Node2D 繪圖節點
	var drawer := Node2D.new()
	drawer.name = "ArrowDrawer"
	arrows_container.add_child(drawer)
	
	# 收集所有連接線資料 - 只繪製可見節點之間的箭頭
	# 可見節點 = 當前節點 + 與當前節點相鄰的節點
	var lines_data: Array = []
	var visible_nodes: Array = [current_node_id]
	visible_nodes.append_array(location_data[current_node_id]["connections"])
	
	var drawn := {}
	
	for id in visible_nodes:
		var from_pos = _get_node_center(id)
		for conn_id in location_data[id]["connections"]:
			# 只繪製連接到可見節點的箭頭
			if not conn_id in visible_nodes:
				continue
			
			var key = str(mini(id, conn_id)) + "-" + str(maxi(id, conn_id))
			if drawn.has(key):
				continue
			drawn[key] = true
			
			var to_pos = _get_node_center(conn_id)
			lines_data.append({
				"from": from_pos,
				"to": to_pos
			})
	
	# 使用 arrow_drawer 腳本繪製
	var arrow_script = preload("res://scripts/arrow_drawer.gd")
	drawer.set_script(arrow_script)
	drawer.set_lines(lines_data)


func _get_node_center(node_id: int) -> Vector2:
	var pos = node_positions[node_id]
	return Vector2(pos.x * 2400.0, pos.y * 1800.0)


# ============================================================
#  角色狀態條（血條 & 理智值）
# ============================================================

# 在玩家棋子上建立血條和理智條
func _init_player_status_bars() -> void:
	var bar_width := 100
	var bar_height := 10
	var spacing := 2
	# 棋子尺寸 128x128，中心在 (64, 64)
	var piece_center_x := 64.0
	
	# --- 血條背景（黑色外框）---
	var hp_bg := ColorRect.new()
	hp_bg.name = "HPBg"
	hp_bg.color = Color(0.1, 0.1, 0.1, 0.9)
	hp_bg.size = Vector2(bar_width, bar_height)
	hp_bg.position = Vector2(piece_center_x - bar_width / 2.0, -28)
	player_piece.add_child(hp_bg)
	
	# --- 血條填充（紅色）---
	var hp_fill := ColorRect.new()
	hp_fill.name = "HPFill"
	hp_fill.color = Color(0.9, 0.15, 0.15, 0.95)
	hp_fill.size = Vector2(bar_width, bar_height)
	hp_fill.position = Vector2(piece_center_x - bar_width / 2.0, -28)
	player_piece.add_child(hp_fill)
	
	# --- 理智條背景（黑色外框）---
	var san_bg := ColorRect.new()
	san_bg.name = "SanBg"
	san_bg.color = Color(0.1, 0.1, 0.1, 0.9)
	san_bg.size = Vector2(bar_width, bar_height)
	san_bg.position = Vector2(piece_center_x - bar_width / 2.0, -28 + bar_height + spacing)
	player_piece.add_child(san_bg)
	
	# --- 理智條填充（藍色）---
	var san_fill := ColorRect.new()
	san_fill.name = "SanFill"
	san_fill.color = Color(0.2, 0.5, 0.9, 0.95)
	san_fill.size = Vector2(bar_width, bar_height)
	san_fill.position = Vector2(piece_center_x - bar_width / 2.0, -28 + bar_height + spacing)
	player_piece.add_child(san_fill)
	
	# 更新顯示
	_update_status_bars()


# 更新血條和理智條的顯示
func _update_status_bars() -> void:
	var bar_width := 100.0
	var piece_center_x := 64.0
	
	# 更新血條（填充偏左對齊，背景保持居中）
	var hp_fill = player_piece.get_node("HPFill") as ColorRect
	if hp_fill:
		var hp_ratio = float(player_hp) / float(player_max_hp)
		hp_fill.size.x = bar_width * hp_ratio
		hp_fill.position.x = piece_center_x - bar_width / 2.0  # 偏左：固定左邊界
	
	# 更新理智條（填充偏左對齊，背景保持居中）
	var san_fill = player_piece.get_node("SanFill") as ColorRect
	if san_fill:
		var san_ratio = float(player_sanity) / float(player_max_sanity)
		san_fill.size.x = bar_width * san_ratio
		san_fill.position.x = piece_center_x - bar_width / 2.0  # 偏左：固定左邊界


# 對角色造成傷害（外部可呼叫）
func damage_player(hp_damage: int = 0, sanity_damage: int = 0) -> void:
	player_hp = clampi(player_hp - hp_damage, 0, player_max_hp)
	player_sanity = clampi(player_sanity - sanity_damage, 0, player_max_sanity)
	_update_status_bars()
	_update_info_panel()
	print("玩家受到傷害 - HP: %d/%d, SAN: %d/%d" % [player_hp, player_max_hp, player_sanity, player_max_sanity])

	
	# 如果 HP 或 SAN 歸零，遊戲結束
	if player_hp <= 0 or player_sanity <= 0:
		print("遊戲結束！")
		# 可以在此加入遊戲結束邏輯


# 回復角色狀態（外部可呼叫）
func heal_player(hp_heal: int = 0, sanity_heal: int = 0) -> void:
	player_hp = clampi(player_hp + hp_heal, 0, player_max_hp)
	player_sanity = clampi(player_sanity + sanity_heal, 0, player_max_sanity)
	_update_status_bars()
	_update_info_panel()
	print("玩家回復 - HP: %d/%d, SAN: %d/%d" % [player_hp, player_max_hp, player_sanity, player_max_sanity])



# ============================================================
#  行動次數（十字架顯示）
# ============================================================

# 更新左上角的行動次數十字架顯示
func _update_action_crosses() -> void:
	var crosses_container = $ActionPanel/Crosses
	if not crosses_container:
		return
	
	var cross_labels = crosses_container.get_children()
	for i in range(cross_labels.size()):
		var label = cross_labels[i] as Label
		if not label:
			continue
		if i < player_actions:
			# 可用行動：黑色實心十字架
			label.text = "✚"
			label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
		else:
			# 已消耗行動：灰色空心十字架
			label.text = "✚"
			label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.5))


# 消耗一次行動（外部可呼叫）
func use_action() -> bool:
	if player_actions <= 0:
		print("沒有剩餘行動次數！")
		return false
	player_actions -= 1
	_update_action_crosses()
	print("消耗一次行動，剩餘: %d/%d" % [player_actions, player_max_actions])
	
	# 行動點歸零時顯示結束回合按鈕
	if player_actions <= 0:
		_show_end_turn_button()
	
	return true


# 抽卡按鈕（消耗 1 行動）
func _on_draw_card_pressed() -> void:
	if player_actions <= 0:
		print("沒有剩餘行動次數，無法抽卡！")
		return
	
	# 消耗一次行動
	use_action()
	
	# 抽一張卡
	card_manager.draw_card()
	
	# 更新手牌面板
	hand_panel.set_available_actions(player_actions)
	hand_panel.set_available_resources(player_resources)
	
	print("消耗 1 行動：抽 1 張卡（目前資源: %d/%d）" % [player_resources, player_max_resources])


# 獲取資源按鈕（消耗 1 行動）
func _on_gain_resource_pressed() -> void:
	if player_actions <= 0:
		print("沒有剩餘行動次數，無法獲取資源！")
		return
	
	# 消耗一次行動
	use_action()
	
	# 獲取 1 點資源
	player_resources = mini(player_resources + 1, player_max_resources)
	_update_resource_display()
	
	# 更新手牌面板
	hand_panel.set_available_actions(player_actions)
	hand_panel.set_available_resources(player_resources)
	
	print("消耗 1 行動：獲得 1 資源（目前資源: %d/%d）" % [player_resources, player_max_resources])


# 重置行動次數（新回合時呼叫）
func reset_actions() -> void:
	player_actions = player_max_actions
	_update_action_crosses()
	_hide_end_turn_button()
	
	# 新回合抽一張牌
	card_manager.draw_card()
	
	# 每回合增加 1 點資源（上限為最大資源數）
	player_resources = mini(player_resources + 1, player_max_resources)
	_update_resource_display()
	print("回合結束，資源 +1，目前: %d/%d" % [player_resources, player_max_resources])
	
	# 更新手牌面板的行動點和資源顯示
	hand_panel.set_available_actions(player_actions)
	hand_panel.set_available_resources(player_resources)
	
	print("行動次數已重置: %d/%d" % [player_actions, player_max_actions])



# ============================================================
#  回合結束按鈕（動態建立）
# ============================================================

var _end_turn_btn: Button = null

func _show_end_turn_button() -> void:
	if _end_turn_btn != null:
		return
	
	_end_turn_btn = Button.new()
	_end_turn_btn.text = "結束回合 ▶"
	_end_turn_btn.size = Vector2(200, 60)
	_end_turn_btn.position = Vector2(size.x / 2.0 - 100.0, size.y / 2.0 - 30.0)
	
	# 使用 StyleBoxFlat 設定白色背景 + 黑色邊框
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 1)
	style.border_color = Color(0, 0, 0, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	_end_turn_btn.add_theme_stylebox_override("normal", style)
	_end_turn_btn.add_theme_stylebox_override("hover", style)
	_end_turn_btn.add_theme_stylebox_override("pressed", style)
	
	_end_turn_btn.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	_end_turn_btn.add_theme_font_size_override("font_size", 22)
	
	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	add_child(_end_turn_btn)
	
	# 淡入
	_end_turn_btn.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(_end_turn_btn, "modulate", Color(1, 1, 1, 1), 0.3)


func _hide_end_turn_button() -> void:
	if _end_turn_btn == null:
		return
	_end_turn_btn.queue_free()
	_end_turn_btn = null


func _on_end_turn_pressed() -> void:
	# 檢查手牌是否超過上限（超過8張必須先棄牌）
	if card_manager.hand.size() > card_manager.MAX_HAND_SIZE:
		print("手牌超過 %d 張，請先棄牌！" % card_manager.MAX_HAND_SIZE)
		# 顯示提示訊息
		_show_hand_full_warning()
		return
	
	print("回合結束，重置行動次數")
	var tween = create_tween()
	tween.tween_property(_end_turn_btn, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(_end_turn_btn, "scale", Vector2(1.1, 1.1), 0.08)
	tween.tween_property(_end_turn_btn, "scale", Vector2(1.0, 1.0), 0.05)
	tween.tween_callback(func():
		reset_actions()
	)


# 顯示手牌已滿警告
func _show_hand_full_warning() -> void:
	var warning = Label.new()
	warning.text = "手牌已滿（%d/%d），請先使用或棄牌！" % [card_manager.hand.size(), card_manager.MAX_HAND_SIZE]
	warning.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 1))
	warning.add_theme_font_size_override("font_size", 20)
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.position = Vector2(size.x / 2.0 - 200.0, size.y / 2.0 - 80.0)
	warning.size = Vector2(400, 40)
	add_child(warning)
	
	# 2 秒後自動消失
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(warning, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(func(): warning.queue_free())


# ============================================================
#  十字架閃爍提示（滑鼠懸停可移動地點時）
# ============================================================

var _blink_tween: Tween = null

# 啟動十字架閃爍效果（只閃爍第一個可用的十字架）
func _start_crosses_blink() -> void:
	# 如果已經在閃爍則不重複啟動
	if _blink_tween and _blink_tween.is_running():
		return
	
	var crosses_container = $ActionPanel/Crosses
	if not crosses_container:
		return
	
	var cross_labels = crosses_container.get_children()
	
	# 找到第一個可用的十字架（已消耗的不閃爍）
	var target_label: Label = null
	for i in range(cross_labels.size()):
		var label = cross_labels[i] as Label
		if not label:
			continue
		if i < player_actions:
			target_label = label
			break
	
	if not target_label:
		return
	
	_blink_tween = create_tween()
	_blink_tween.set_loops()
	
	# 只在第一個可用十字架上閃爍，提示只消耗一個行動點
	_blink_tween.tween_method(_set_cross_alpha.bind(target_label), 1.0, 0.3, 0.3)
	_blink_tween.tween_method(_set_cross_alpha.bind(target_label), 0.3, 1.0, 0.3)


# 停止十字架閃爍效果
func _stop_crosses_blink() -> void:
	if _blink_tween:
		_blink_tween.kill()
		_blink_tween = null
	
	# 恢復所有十字架到正常顏色
	var crosses_container = $ActionPanel/Crosses
	if not crosses_container:
		return
	
	var cross_labels = crosses_container.get_children()
	for i in range(cross_labels.size()):
		var label = cross_labels[i] as Label
		if not label:
			continue
		if i < player_actions:
			label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
		else:
			label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.5))


# 輔助函數：設定十字架的透明度
func _set_cross_alpha(alpha: float, label: Label) -> void:
	var color = Color(0, 0, 0, alpha)
	label.add_theme_color_override("font_color", color)


# ============================================================
#  多方向精靈圖動畫系統
#  精靈圖：1152x576 = 10列 x 5行
#  每幀尺寸：115x115（整數，避免剪裁偏移）
#  行0: idle（站立）  行1: 向上 ↑  行2: 向下 ↓  行3: 向左 ←  行4: 向右 →
#  中心點：每幀中心在 (57.5, 57.5)，Sprite2D 位置設為 (64, 64) 使棋子居中
# ============================================================

enum AnimDir { IDLE, UP, DOWN, LEFT, RIGHT }

# 動畫參數
const _anim_frame_count: int = 10          # 每行 10 幀
const _anim_frame_w: int = 115             # 每幀寬度（整數）
const _anim_frame_h: int = 115             # 每幀高度（整數）
var _anim_current_frame: int = 0
var _anim_timer: float = 0.0
var _anim_speed: float = 0.1               # 每幀間隔（秒）
var _anim_dir: int = AnimDir.IDLE          # 目前方向
var _anim_playing: bool = false            # 是否正在播放行走動畫

# 初始化精靈圖動畫
func _init_sprite_animation() -> void:
	if not player_sprite or not player_sprite.texture:
		return
	
	# 設定 Sprite2D 使用 region
	player_sprite.region_enabled = true
	# 預設顯示 idle 第 0 幀
	_set_sprite_frame(AnimDir.IDLE, 0)

# 設定精靈圖顯示某行某幀
func _set_sprite_frame(dir: int, frame: int) -> void:
	if not player_sprite:
		return
	var x = frame * _anim_frame_w
	var y = dir * _anim_frame_h
	player_sprite.region_rect = Rect2(x, y, _anim_frame_w, _anim_frame_h)

# 開始行走動畫（指定方向）
func _start_walk_animation(dir: int) -> void:
	_anim_dir = dir
	_anim_current_frame = 0
	_anim_timer = 0.0
	_anim_playing = true
	_set_sprite_frame(dir, 0)

# 停止行走動畫，回到 idle
func _stop_walk_animation() -> void:
	_anim_playing = false
	_set_sprite_frame(AnimDir.IDLE, 0)

# 根據兩個節點 ID 計算移動方向
func _get_move_dir(from_id: int, to_id: int) -> int:
	var from_pos = node_positions[from_id]
	var to_pos = node_positions[to_id]
	var dx = to_pos.x - from_pos.x
	var dy = to_pos.y - from_pos.y
	
	# 判斷主要方向
	if abs(dx) > abs(dy):
		return AnimDir.RIGHT if dx > 0 else AnimDir.LEFT
	else:
		return AnimDir.DOWN if dy > 0 else AnimDir.UP

# _process 每幀更新動畫
func _process(delta: float) -> void:
	if not _anim_playing:
		return
	_anim_timer += delta
	if _anim_timer >= _anim_speed:
		_anim_timer -= _anim_speed
		_anim_current_frame = (_anim_current_frame + 1) % _anim_frame_count
		_set_sprite_frame(_anim_dir, _anim_current_frame)


# ============================================================
#  開場對話（參考神之天平風格）
# ============================================================

var _is_dialogue_open: bool = false

# 顯示開場對話
func _show_entry_dialogue() -> void:
	_is_dialogue_open = true
	dialogue_speaker.text = "主角"
	dialogue_content.text = "那我就進去看看吧……"
	dialogue_overlay.visible = true
	
	# 對話框淡入動畫
	dialogue_overlay.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(dialogue_overlay, "modulate", Color(1, 1, 1, 1), 0.3)


# 關閉對話框
func _close_dialogue() -> void:
	if not _is_dialogue_open:
		return
	_is_dialogue_open = false
	
	# 對話框淡出動畫
	var tween = create_tween()
	tween.tween_property(dialogue_overlay, "modulate", Color(1, 1, 1, 0), 0.2)
	tween.tween_callback(func(): dialogue_overlay.visible = false)
