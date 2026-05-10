extends Control

# ============================================================
#  Galgame 對話系統模板 — 主控制器
#  功能：對話播放、逐字顯示、選項分支、立繪管理、
#        背景切換、對話歷史、自動/快轉模式、存檔/讀檔
# ============================================================

# ----- 資源對照表 -------------------------------------------

const PORTRAIT_MAP := {
	"主角": preload("res://assets/characters/boy.png"),
	"女主角": preload("res://assets/characters/heroine.png"),
}

const BACKGROUND_MAP := {
	"school1": preload("res://assets/backgrounds/Gemini_Generated_Image_6zsyhp6zsyhp6zsy.png"),
	"school2": preload("res://assets/backgrounds/Gemini_Generated_Image_p3lf59p3lf59p3lf.png"),
	"rooftop": preload("res://assets/backgrounds/Gemini_Generated_Image_uggepduggepdugge.png"),
	"地牢": preload("res://assets/backgrounds/地牢.png"),
}

var DEFAULT_BG := preload("res://assets/backgrounds/地牢.png")

# ----- 狀態變數 ---------------------------------------------

var dialogue_data: Array = []
var current_index: int = 0
var reveal_speed: float = 50.0       # 字/秒
var reveal_progress: float = 0.0
var is_waiting_choice: bool = false
var current_text: String = ""
var is_finished: bool = false
var dialogue_history: Array[Dictionary] = []
var is_auto_mode: bool = false
var auto_timer: float = 0.0
var auto_delay: float = 1.5          # 自動模式停頓秒數
var is_skipping: bool = false

# ----- 節點參照 ---------------------------------------------

@onready var background: TextureRect = $Background
@onready var left_portrait: TextureRect = $LeftPortrait
@onready var center_portrait: TextureRect = $CenterPortrait
@onready var right_portrait: TextureRect = $RightPortrait
@onready var dark_overlay: ColorRect = $DarkOverlay

@onready var dialogue_panel: Panel = $DialoguePanel
@onready var speaker_label: Label = $DialoguePanel/Margin/VBox/Speaker
@onready var content_label: RichTextLabel = $DialoguePanel/Margin/VBox/Content
@onready var choices_box: VBoxContainer = $DialoguePanel/Margin/VBox/Choices

@onready var menu_buttons: HBoxContainer = $MenuButtons
@onready var save_button: Button = $MenuButtons/SaveButton
@onready var load_button: Button = $MenuButtons/LoadButton
@onready var auto_button: Button = $MenuButtons/AutoButton
@onready var skip_button: Button = $MenuButtons/SkipButton
@onready var back_title_button: Button = $MenuButtons/BackTitleButton

@onready var save_panel: Panel = $SavePanel
@onready var preview_text: RichTextLabel = $SavePanel/VBox/PreviewText
@onready var confirm_save_button: Button = $SavePanel/VBox/HBox/ConfirmSaveButton
@onready var cancel_save_button: Button = $SavePanel/VBox/HBox/CancelSaveButton

@onready var load_panel: Panel = $LoadPanel
@onready var load_preview_text: RichTextLabel = $LoadPanel/VBox/PreviewText
@onready var confirm_load_button: Button = $LoadPanel/VBox/HBox/ConfirmLoadButton
@onready var cancel_load_button: Button = $LoadPanel/VBox/HBox/CancelLoadButton

@onready var history_panel: Panel = $HistoryPanel
@onready var history_scroll: ScrollContainer = $HistoryPanel/MarginContainer/ScrollContainer
@onready var history_container: VBoxContainer = $HistoryPanel/MarginContainer/ScrollContainer/HistoryContainer
@onready var close_history_button: Button = $HistoryPanel/CloseHistoryButton


# ============================================================
#  初始設定
# ============================================================

func _ready() -> void:
	# 按鈕事件
	save_button.pressed.connect(_open_save_preview)
	load_button.pressed.connect(_open_load_preview)
	auto_button.pressed.connect(_toggle_auto)
	skip_button.pressed.connect(_toggle_skip)
	back_title_button.pressed.connect(_go_back_title)
	confirm_save_button.pressed.connect(save_game)
	cancel_save_button.pressed.connect(_close_save_preview)
	confirm_load_button.pressed.connect(load_game)
	cancel_load_button.pressed.connect(_close_load_preview)
	close_history_button.pressed.connect(_close_history)

	# 初始隱藏
	save_panel.visible = false
	load_panel.visible = false
	history_panel.visible = false
	# 設定暗色覆蓋層著色器
	var spot_material := ShaderMaterial.new()
	spot_material.shader = preload("res://shaders/spotlight.gdshader")
	dark_overlay.material = spot_material

	# 載入對話資料
	_load_dialogue()
	_show_current_line()


# ============================================================
#  對話資料載入
# ============================================================

func _load_dialogue() -> void:
	var file = FileAccess.open("res://data/dialogue.json", FileAccess.READ)
	if not file:
		push_error("無法開啟 dialogue.json")
		return
	var json_string = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_string)
	if error == OK:
		dialogue_data = json.data
		print("對話資料載入成功，共 %d 行" % dialogue_data.size())
	else:
		push_error("JSON 解析錯誤: ", json.get_error_message())


# ============================================================
#  顯示目前對話行
# ============================================================

func _show_current_line() -> void:
	if dialogue_data.is_empty():
		return

	_clear_choices()
	is_waiting_choice = false

	var line: Dictionary = dialogue_data[current_index]
	var speaker: String = line.get("name", "")
	speaker_label.text = speaker
	current_text = line.get("text", "")

	# 文字重置
	content_label.text = current_text
	reveal_progress = 0.0
	content_label.visible_characters = 0

	# --- 背景強制設為地牢 ---
	background.texture = DEFAULT_BG
	# --- 對話特效 ---
	var effect = line.get("effect", "")
	match effect:
		"shock":
			_trigger_shake()
		"darken":
			_set_lighting("darken")
		"light_candle":
			_set_lighting("light_candle")

	# --- 立繪自動顯示 ---
	# 主角顯示在中央，其他角色顯示在左側
	if speaker == "主角":
		center_portrait.texture = PORTRAIT_MAP.get(speaker)
		left_portrait.texture = null
	else:
		center_portrait.texture = null
		if PORTRAIT_MAP.has(speaker):
			left_portrait.texture = PORTRAIT_MAP[speaker]
		else:
			left_portrait.texture = null
	right_portrait.texture = null

	# --- 發話者高亮 ---
	_update_portrait_highlight(speaker)

	# --- 選項 ---
	if line.has("choices"):
		is_waiting_choice = true
		for choice in line["choices"]:
			var button := Button.new()
			button.text = choice.get("text", "")
			button.add_theme_font_size_override("font_size", 24)
			button.pressed.connect(_on_choice_selected.bind(choice.get("next", current_index + 1)))
			choices_box.add_child(button)

	# --- 記錄歷史 ---
	dialogue_history.append({
		"speaker": speaker,
		"text": current_text
	})

	# --- 主角立繪震動特效（只在主角說話時觸發）---
func _trigger_shake() -> void:
	var tween := create_tween()
	var original_pos := center_portrait.position
	for i in 6:
		tween.tween_callback(_apply_shake.bind(8.0 - i))
		tween.tween_interval(0.03)
	tween.tween_callback(_reset_shake.bind(original_pos))

func _apply_shake(strength: float) -> void:
	center_portrait.position = Vector2(
		randf_range(-strength, strength),
		randf_range(-strength, strength)
	)

func _reset_shake(original_pos: Vector2) -> void:
	center_portrait.position = original_pos

# --- 燈光控制 ---
func _set_lighting(mode: String) -> void:
	var mat := dark_overlay.material as ShaderMaterial
	if not mat:
		return
	match mode:
		"darken":
			mat.set_shader_parameter("darkness", 0.85)
			mat.set_shader_parameter("spotlight_radius", Vector2(0, 0))
		"light_candle":
			mat.set_shader_parameter("darkness", 0.85)
			mat.set_shader_parameter("spotlight_radius", Vector2(0.62, 0.34))
			mat.set_shader_parameter("spotlight_center", Vector2(0.5, 0.55))

# ============================================================
#  立繪控制
# ============================================================

func _update_single_portrait(rect: TextureRect, role_key: String) -> void:
	if role_key.is_empty():
		# 清空立繪
		rect.texture = null
		return
	if PORTRAIT_MAP.has(role_key):
		rect.texture = PORTRAIT_MAP[role_key]
	else:
		print("警告：找不到角色 '%s' 的立繪" % role_key)


func _update_portrait_highlight(speaker: String) -> void:
	# 根據當前發話者調整立繪明暗
	var dim := Color(0.5, 0.5, 0.5, 0.7)
	var bright := Color(1.0, 1.0, 1.0, 1.0)

	if speaker == "主角":
		center_portrait.modulate = bright
		left_portrait.modulate = dim
	else:
		center_portrait.modulate = dim
		left_portrait.modulate = bright
	right_portrait.modulate = dim


# ============================================================
#  對話推進
# ============================================================

func _advance_dialogue() -> void:
	if is_finished:
		return

	# 字幕還沒跑完 → 直接跳完整
	if content_label.visible_characters < current_text.length():
		content_label.visible_characters = current_text.length()
		return

	# 等待選項中 → 不推進
	if is_waiting_choice:
		return

	var current_line = dialogue_data[current_index]
	if current_line.has("next"):
		current_index = current_line["next"]
	else:
		current_index += 1

	if current_index >= dialogue_data.size():
		current_index = dialogue_data.size() - 1
		is_finished = true
		# 對話結束，進入卡牌地圖
		get_tree().change_scene_to_file("res://scenes/Map.tscn")
		return

	_show_current_line()


func _on_choice_selected(next_index: int) -> void:
	current_index = clampi(next_index, 0, dialogue_data.size() - 1)
	_show_current_line()


func _clear_choices() -> void:
	for child in choices_box.get_children():
		child.queue_free()


# ============================================================
#  _process — 逐字動畫 + 自動模式
# ============================================================

func _process(delta: float) -> void:
	# --- 逐字出現 ---
	if content_label.visible_characters < current_text.length():
		reveal_progress += reveal_speed * delta
		content_label.visible_characters = mini(int(reveal_progress), current_text.length())

	# --- 快轉模式：文字一完整就自動跳下一句 ---
	if is_skipping and not is_waiting_choice and not is_finished:
		if content_label.visible_characters >= current_text.length():
			_advance_dialogue()
		return

	# --- 自動模式：文字完整後等數秒自動跳 ---
	if is_auto_mode and not is_waiting_choice and not is_finished:
		if content_label.visible_characters >= current_text.length():
			auto_timer += delta
			if auto_timer >= auto_delay:
				auto_timer = 0.0
				_advance_dialogue()


# ============================================================
#  輸入處理
# ============================================================

func _input(event: InputEvent) -> void:
	# --- 鍵盤快捷鍵 ---
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F5:
				_open_save_preview()
			KEY_F9:
				_open_load_preview()
			KEY_A:
				_toggle_auto()
			KEY_S:
				_toggle_skip()
			KEY_H, KEY_UP:
				if not history_panel.visible:
					_open_history()
			KEY_ESCAPE:
				if save_panel.visible:
					_close_save_preview()
				elif load_panel.visible:
					_close_load_preview()
				elif history_panel.visible:
					_close_history()

	# --- 滑鼠點擊對話面板 → 推進 ---
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			# 如果任何面板開著，不推進對話
			if save_panel.visible or load_panel.visible or history_panel.visible:
				return
			# 點擊對話面板範圍內才推進
			if dialogue_panel.get_global_rect().has_point(mouse_event.position):
				_advance_dialogue()


# ============================================================
#  自動 / 快轉 模式切換
# ============================================================

func _toggle_auto() -> void:
	is_auto_mode = not is_auto_mode
	if is_auto_mode:
		is_skipping = false
		auto_timer = 0.0
		auto_button.text = "自動 ON"
		skip_button.text = "快轉"
	else:
		auto_button.text = "自動 OFF"


func _toggle_skip() -> void:
	is_skipping = not is_skipping
	if is_skipping:
		is_auto_mode = false
		skip_button.text = "快轉 ON"
		auto_button.text = "自動 OFF"
	else:
		skip_button.text = "快轉"


# ============================================================
#  對話歷史
# ============================================================

func _open_history() -> void:
	history_panel.visible = true
	# 清空舊內容再重建
	for child in history_container.get_children():
		child.queue_free()

	for entry in dialogue_history:
		var speaker = entry.get("speaker", "")
		var text = entry.get("text", "")
		var label := RichTextLabel.new()
		label.add_theme_font_size_override("normal_font_size", 22)
		if speaker.is_empty():
			label.text = "[color=#aaaaaa]%s[/color]" % text
		else:
			label.text = "[b]%s[/b]\n%s" % [speaker, text]
		label.fit_content = true
		label.scroll_active = false
		label.add_theme_constant_override("separation", 4)
		history_container.add_child(label)

	# 自動滾到最下方
	await get_tree().process_frame
	history_scroll.scroll_vertical = int(history_scroll.get_v_scroll_bar().max_value)


func _close_history() -> void:
	history_panel.visible = false


# ============================================================
#  存檔 / 讀檔
# ============================================================

const SAVE_PATH := "user://savegame.json"


func _open_save_preview() -> void:
	save_panel.visible = true
	var speaker = speaker_label.text
	if speaker != "":
		preview_text.text = "進度: [%s]\n%s" % [speaker, current_text]
	else:
		preview_text.text = "進度: \n%s" % current_text


func _close_save_preview() -> void:
	save_panel.visible = false


func _open_load_preview() -> void:
	load_panel.visible = true
	if not FileAccess.file_exists(SAVE_PATH):
		load_preview_text.text = "沒有找到存檔紀錄。"
		confirm_load_button.disabled = true
		return

	confirm_load_button.disabled = false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		load_preview_text.text = "無法讀取存檔。"
		return

	var json_string = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		load_preview_text.text = "存檔檔案解析失敗。"
		return

	var save_data = json.data
	if save_data.has("current_index"):
		var saved_idx = save_data["current_index"]
		if saved_idx >= 0 and saved_idx < dialogue_data.size():
			var line = dialogue_data[saved_idx]
			var speaker = line.get("name", "")
			var text = line.get("text", "")
			load_preview_text.text = "紀錄: [%s]\n%s" % [speaker, text] if speaker != "" else "紀錄: \n%s" % text
		else:
			load_preview_text.text = "存檔資料異常。"
	else:
		load_preview_text.text = "存檔格式不符。"


func _close_load_preview() -> void:
	load_panel.visible = false


func save_game() -> void:
	var save_data = {
		"current_index": current_index
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		print("遊戲已存檔，進度: ", current_index)
		_close_save_preview()
	else:
		push_error("存檔失敗")


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("沒有存檔檔案")
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var json_string = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		return

	var save_data = json.data
	if save_data.has("current_index"):
		current_index = save_data["current_index"]
		is_finished = false
		is_auto_mode = false
		is_skipping = false
		auto_button.text = "自動 OFF"
		skip_button.text = "快轉"
		# 清空歷史（讀檔後舊歷史不連續）
		dialogue_history.clear()
		_show_current_line()
		print("遊戲已讀檔，進度: ", current_index)
		_close_load_preview()


# ============================================================
#  返回標題
# ============================================================

func _go_back_title() -> void:
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")
