# 殺戮尖塔 (Slay the Spire) 卡牌系統參考文檔

> 參考版本：正式版 (2019)
> 用途：供 Arkham Horror 風格 Galgame 卡牌系統設計參考

---

## 一、卡牌拖拽 (Drag & Drop) 機制

### 1.1 拖拽流程

```
滑鼠按下卡牌
  ↓
卡牌放大 + 跟隨滑鼠（脫離手牌佈局）
  ↓
滑鼠拖拽到目標區域
  ├── 拖到敵方單位 → 攻擊/效果目標選定
  ├── 拖到己方單位 → 增益/治療目標選定
  └── 拖到空白處/放開 → 卡牌回到手牌原位（動畫回彈）
  ↓
確認使用 → 卡牌飛向目標 → 執行效果 → 卡牌消失（進入棄牌堆）
```

### 1.2 關鍵實作細節

| 項目 | 說明 |
|------|------|
| **拖拽狀態** | 卡牌進入拖拽模式時，從 HBoxContainer 中移除，改為跟隨滑鼠的浮動節點 |
| **視覺回饋** | 拖拽時卡牌放大 1.2x~1.5x，帶有陰影效果，透明度不變 |
| **目標高亮** | 拖拽到可互動目標上時，目標邊框發光/閃爍 |
| **取消拖拽** | 右鍵取消 / 拖到非目標區域放開 / 按 ESC，卡牌動畫回彈到手牌原位 |
| **Z-index** | 拖拽中的卡牌在最上層，不受其他 UI 遮擋 |

### 1.3 Godot 實作建議

```gdscript
# 卡牌腳本中的拖拽邏輯
extends Control

var is_dragging: bool = false
var drag_offset: Vector2
var original_parent: Node
var original_index: int

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _start_drag()
        elif is_dragging:
            _end_drag()

func _start_drag() -> void:
    is_dragging = true
    # 記錄原始位置
    original_parent = get_parent()
    original_index = get_index()
    
    # 從佈局中移除，改為跟隨滑鼠
    reparent(get_tree().root)  # 移到根節點避免遮擋
    scale = Vector2(1.3, 1.3)
    # 加入陰影效果
    material = preload("res://materials/card_drag_shader.tres")

func _end_drag() -> void:
    is_dragging = false
    # 檢查是否落在有效目標上
    var target = _get_target_under_mouse()
    if target:
        _play_card(target)
    else:
        _return_to_hand()  # 回彈動畫

func _return_to_hand() -> void:
    # 動畫回彈到手牌原位
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector2(1, 1), 0.2)
    tween.parallel().tween_property(self, "position", original_position, 0.3)
    tween.tween_callback(func():
        reparent(original_parent)
        move_child(original_index)
    )
```

---

## 二、手牌放置位置與佈局

### 2.1 手牌扇形佈局

殺戮尖塔的手牌採用**扇形排列**，核心參數：

```
手牌數量: N
扇形角度: 60°~80°（總張開角度）
每張卡牌寬度: ~120px
卡牌重疊量: 40%~60%（牌多時重疊更多）
基準點: 螢幕底部中央
```

### 2.2 佈局計算公式

```gdscript
# 扇形佈局演算法
func calculate_hand_positions(card_count: int, screen_width: float) -> Array[Vector2]:
    var positions: Array[Vector2] = []
    if card_count <= 0:
        return positions
    
    var base_y: float = screen_height - 200  # 底部 Y 位置
    var center_x: float = screen_width / 2.0
    
    # 扇形參數
    var max_angle: float = deg_to_rad(35.0)  # 最大偏移角度（單側）
    var spread: float = 400.0                # 水平展開寬度
    
    if card_count == 1:
        positions.append(Vector2(center_x, base_y))
        return positions
    
    for i in range(card_count):
        var t: float = float(i) / float(card_count - 1)  # 0.0 ~ 1.0
        var angle: float = lerp(-max_angle, max_angle, t)
        
        # 水平位置：扇形展開
        var x: float = lerp(center_x - spread/2, center_x + spread/2, t)
        # 垂直位置：中間高兩邊低（弧形）
        var y: float = base_y - abs(sin(angle)) * 60.0
        
        positions.append(Vector2(x, y))
    
    return positions
```

### 2.3 卡牌縮放與重疊

| 手牌數量 | 縮放比例 | 重疊量 | 說明 |
|----------|----------|--------|------|
| 1~3 張 | 1.0x | 0% | 完整顯示 |
| 4~6 張 | 0.9x | 20% | 輕微重疊 |
| 7~10 張 | 0.8x | 40% | 明顯重疊 |
| 10+ 張 | 0.7x | 55% | 緊湊排列 |

### 2.4 懸停放大效果

```
滑鼠懸停某張卡牌
  ↓
該卡牌向上浮起（Y 軸 -40px）
  ↓
卡牌放大 1.15x
  ↓
相鄰卡牌向兩側稍微推開（動畫過渡）
  ↓
卡牌資訊詳細顯示（費用、效果描述等）
```

```gdscript
# 懸停放大邏輯
func _on_card_hover(card_ui: Control, index: int) -> void:
    # 該卡牌浮起
    var tween = create_tween()
    tween.tween_property(card_ui, "position:y", card_ui.position.y - 40, 0.15)
    tween.parallel().tween_property(card_ui, "scale", Vector2(1.15, 1.15), 0.15)
    
    # 相鄰卡牌推開
    _push_adjacent_cards(index, 20)

func _on_card_unhover(card_ui: Control, index: int) -> void:
    # 恢復原位
    var tween = create_tween()
    tween.tween_property(card_ui, "position:y", original_y, 0.15)
    tween.parallel().tween_property(card_ui, "scale", Vector2(1.0, 1.0), 0.15)
    
    # 相鄰卡牌恢復
    _push_adjacent_cards(index, 0)
```

### 2.5 手牌上限

- **預設手牌上限**: 10 張
- **超過上限時**: 抽牌時如果手牌已滿，卡牌直接進入棄牌堆
- **回合結束**: 手牌保留（不棄牌），與爐石不同

---

## 三、地圖互動設計

### 3.1 地圖節點類型

| 節點類型 | 圖示 | 說明 |
|----------|------|------|
| **普通怪物 (Monster)** | 劍 | 戰鬥獎勵：金幣+卡牌 |
| **菁英怪物 (Elite)** | 火焰劍 | 高難度戰鬥，獎勵更好 |
| **Boss** | 王冠 | 章節最終首領 |
| **休息 (Rest)** | 營火 | 回血/升級卡牌 |
| **寶箱 (Treasure)** | 寶箱 | 獲得遺物 |
| **商店 (Shop)** | 金幣 | 購買卡牌/遺物/藥水 |
| **隨機事件 (Event)** | 問號 | 隨機劇情選擇 |
| **未知 (Unknown)** | 迷霧 | 首次探索時揭示類型 |

### 3.2 地圖路徑系統

```
核心設計：
├── 分層結構：每層 3~5 個節點
├── 強制前進：只能向前，不能回頭
├── 分支路徑：玩家選擇路線
└── 路徑可視化：連接線顯示可選路線
```

### 3.3 地圖互動流程

```
玩家點擊節點
  ↓
檢查是否可到達（相鄰且在前方）
  ├── 不可到達 → 提示"無法前往"
  └── 可到達 → 進入節點事件
        ↓
根據節點類型觸發不同事件：
  ├── 怪物 → 進入戰鬥場景
  ├── 休息 → 打開休息介面（回血/升級）
  ├── 寶箱 → 獲得遺物動畫
  ├── 商店 → 打開商店介面
  └── 事件 → 顯示事件卡牌/選擇
```

### 3.4 地圖視覺設計

```
地圖背景：深色羊皮紙風格
節點圖示：簡潔的像素/向量圖標
路徑線條：發光的連接線（已走過變暗）
當前位置：閃爍/發光標記
已訪問節點：打勾/變灰
鎖定節點：迷霧遮蓋
```

### 3.5 與我們遊戲的差異對比

| 項目 | 殺戮尖塔 | 我們的遊戲 (Arkham Horror 風格) |
|------|----------|-------------------------------|
| **地圖結構** | 線性分層，只能前進 | 自由探索，可來回移動 |
| **節點解鎖** | 選擇路徑後自動解鎖 | 需要消耗行動點解鎖/調查 |
| **戰鬥** | 回合制卡牌戰鬥 | 擲骰判定 + 卡牌輔助 |
| **手牌** | 每回合抽滿到上限 | 每回合抽 1 張，行動點消耗 |
| **卡牌使用** | 拖拽到目標 | 點擊使用（目前） |
| **資源系統** | 能量 (Energy) 每回合 3 點 | 行動點 (Actions) 每回合 3 點 |
| **地圖返回** | 不可返回 | 可返回已訪問節點 |

---

## 四、卡牌使用流程（殺戮尖塔 vs 我們的設計）

### 4.1 殺戮尖塔流程

```
1. 玩家拖拽卡牌
2. 卡牌跟隨滑鼠
3. 滑鼠移到目標上 → 目標高亮
4. 放開滑鼠 → 卡牌飛向目標
5. 消耗能量
6. 執行效果（動畫+數值）
7. 卡牌進入棄牌堆
8. 檢查是否觸發其他效果（如能力）
```

### 4.2 我們的流程（目前設計）

```
1. 玩家點擊卡牌
2. 檢查行動點是否足夠
3. 消耗行動點
4. 執行效果
5. 卡牌從手牌移除（裝備類卡牌進入裝備插槽）
6. 更新 UI
```

### 4.3 可改進方向

1. **加入拖拽機制**：讓卡牌使用更有操作感
2. **目標選擇**：部分卡牌需要選擇目標（如治療指定自己/隊友）
3. **使用動畫**：卡牌飛向目標的過渡動畫
4. **取消使用**：點擊卡牌後可取消（右鍵/ESC）
5. **懸停預覽**：懸停卡牌時顯示詳細效果說明

---

## 五、關鍵 UI 尺寸參考

```
螢幕解析度: 1920x1080 (或 16:9 比例)

手牌區域:
  Y 位置: 底部往上 180~220px
  卡牌尺寸: 120x170px (寬x高)
  卡牌縮放: 0.7x~1.0x

地圖區域:
  地圖尺寸: 全螢幕
  節點按鈕: 100x60px
  節點間距: 150~200px

資訊面板:
  位置: 左上角
  寬度: 300px
  內容: 角色狀態、裝備、能力值

行動點顯示:
  位置: 資訊面板下方
  樣式: 十字架/能量寶石圖標
```

---

## 六、總結建議

1. **短期可實作**：
   - 卡牌懸停放大效果（提升操作感）
   - 卡牌使用動畫（飛向目標）
   - 右鍵取消使用

2. **中期目標**：
   - 拖拽系統（拖牌到目標）
   - 扇形手牌佈局
   - 目標選擇高亮

3. **長期願景**：
   - 卡牌連鎖效果
   - 動畫序列系統
   - 完整的戰鬥場景
