extends Node

# ============================================================
#  卡牌管理器
#  管理牌組、手牌、抽牌、使用卡牌等邏輯
#  參考 Arkham Horror 卡牌系統
# ============================================================

class_name CardManager

# 所有卡牌資料庫
var all_cards: Dictionary = {}

# 當前牌組（剩餘卡牌 ID 列表）
var deck: Array[String] = []

# 當前手牌（卡牌資料列表）
var hand: Array[Dictionary] = []

# 棄牌堆（已使用或丟棄的卡牌 ID 列表）
var discard_pile: Array[String] = []

# 已裝備的卡牌（插槽系統）
var equipped: Dictionary = {
	"hand": null,       # 手部（武器/盾牌）
	"accessory": null   # 飾品（蠟燭/鑰匙等）
}

# 信號
signal hand_updated(hand_cards: Array)
signal deck_updated(deck_count: int)
signal discard_updated(discard_count: int)
signal card_played(card_data: Dictionary)
signal equipment_changed(slot: String, card_data)


func _ready() -> void:
	_load_all_cards()


# 載入所有卡牌資料
func _load_all_cards() -> void:
	var file = FileAccess.open("res://data/cards.json", FileAccess.READ)
	if not file:
		push_error("無法開啟 cards.json")
		return
	
	var json_string = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("cards.json 解析錯誤: ", json.get_error_message())
		return
	
	var cards_array: Array = json.data
	for card in cards_array:
		var id: String = card.get("id", "")
		if not id.is_empty():
			all_cards[id] = card
	
	print("卡牌資料載入成功，共 %d 張" % all_cards.size())


# 初始化牌組（根據卡牌 ID 列表）
func init_deck(card_ids: Array[String]) -> void:
	deck = card_ids.duplicate()
	deck.shuffle()
	print("牌組初始化完成，共 %d 張" % deck.size())
	deck_updated.emit(deck.size())


# 初始化預設牌組（給新遊戲使用）
func init_default_deck() -> void:
	var default_ids: Array[String] = [
		"rusty_sword",
		"wooden_shield",
		"candle",
		"old_key",
		"healing_potion",
		"sanity_potion",
		"fire_spell",
		"light_spell",
		"shield_spell",
		"sneak",
		"observation",
		"dodge",
		"torch",
		"lockpick",
		"rage"
	]
	init_deck(default_ids)


# 抽一張牌
func draw_card() -> Dictionary:
	if deck.is_empty():
		print("牌組已空，無法抽牌！")
		return {}
	
	var card_id = deck.pop_front()
	var card_data = all_cards.get(card_id, {}).duplicate(true)
	if card_data.is_empty():
		print("找不到卡牌: %s" % card_id)
		return {}
	
	hand.append(card_data)
	hand_updated.emit(hand)
	deck_updated.emit(deck.size())
	print("抽牌: %s，手牌: %d 張" % [card_data.get("name", ""), hand.size()])
	return card_data


# 抽多張牌
func draw_cards(count: int) -> void:
	for i in range(count):
		draw_card()


# 使用卡牌（從手牌中移除並執行效果）
func use_card(card_index: int) -> bool:
	if card_index < 0 or card_index >= hand.size():
		return false
	
	var card_data = hand[card_index]
	var _card_id = card_data.get("id", "")
	
	# 檢查是否有插槽需求
	var slot = card_data.get("slot", null)
	if slot != null:
		# 如果是裝備類卡牌，裝備到對應插槽
		return _equip_card(card_index, slot)
	
	# 非裝備類卡牌（一次性使用）
	var card_id = card_data.get("id", "")
	hand.remove_at(card_index)
	discard_pile.append(card_id)
	hand_updated.emit(hand)
	discard_updated.emit(discard_pile.size())
	card_played.emit(card_data)
	print("使用卡牌: %s，棄牌堆: %d 張" % [card_data.get("name", ""), discard_pile.size()])
	return true


# 裝備卡牌到插槽
func _equip_card(card_index: int, slot: String) -> bool:
	if card_index < 0 or card_index >= hand.size():
		return false
	
	var card_data = hand[card_index]
	
	# 如果該插槽已有裝備，先卸下（回到手牌）
	if equipped[slot] != null:
		var old_card = equipped[slot]
		hand.append(old_card)
		print("卸下裝備: %s" % old_card.get("name", ""))
	
	# 裝備新卡牌
	equipped[slot] = card_data
	hand.remove_at(card_index)
	
	hand_updated.emit(hand)
	equipment_changed.emit(slot, card_data)
	print("裝備 %s: %s" % [slot, card_data.get("name", "")])
	return true


# 卸下裝備（回到手牌）
func unequip_slot(slot: String) -> bool:
	if equipped[slot] == null:
		return false
	
	var card_data = equipped[slot]
	hand.append(card_data)
	equipped[slot] = null
	
	hand_updated.emit(hand)
	equipment_changed.emit(slot, null)
	print("卸下 %s 裝備" % slot)
	return true


# 獲取手牌
func get_hand() -> Array[Dictionary]:
	return hand


# 獲取牌組剩餘數量
func get_deck_count() -> int:
	return deck.size()

# 獲取棄牌堆數量
func get_discard_count() -> int:
	return discard_pile.size()


# 檢查是否有足夠資源使用卡牌
func can_play_card(card_index: int, available_actions: int, available_resources: int = 0) -> bool:
	if card_index < 0 or card_index >= hand.size():
		return false
	
	var action_cost = hand[card_index].get("cost", 0)
	var resource_cost = hand[card_index].get("resource_cost", 0)
	
	if available_actions < action_cost:
		return false
	if available_resources < resource_cost:
		return false
	
	return true


# 洗牌
func shuffle_deck() -> void:
	deck.shuffle()
	print("牌組已洗牌")


# 重置牌組（將所有手牌和裝備收回牌組並重新洗牌）
func reset_deck() -> void:
	# 收回手牌
	for card in hand:
		deck.append(card.get("id", ""))
	hand.clear()
	
	# 收回裝備
	for slot in equipped.keys():
		if equipped[slot] != null:
			deck.append(equipped[slot].get("id", ""))
			equipped[slot] = null
	
	deck.shuffle()
	hand_updated.emit(hand)
	deck_updated.emit(deck.size())
	equipment_changed.emit("hand", null)
	equipment_changed.emit("accessory", null)
	print("牌組已重置，共 %d 張" % deck.size())
