# 完整遭遇卡系統實作計畫

根據 Arkham Horror LCG 遭遇卡系統設計，整合到 Godot galgame 專案中。

---

## 📦 1. 遭遇卡資料結構（cards.json 新增）

在 `cards.json` 中新增 15+ 張遭遇卡，分為四種類型：

| 類型 | 子類型 | 說明 | 範例 |
|------|--------|------|------|
| `encounter` | `treachery` | 抽到時觸發負面效果 | 失憶詛咒、蜘蛛陷阱 |
| `encounter` | `enemy` | 生成敵人，需戰鬥/閃避 | 地牢鼠群、骷髏戰士 |
| `encounter` | `hazard` | 損壞裝備或施加狀態 | 腐蝕陷阱、詛咒之霧 |
| `encounter` | `event` | 中立/正面隨機事件 | 神秘商人、隱藏寶藏 |

**遭遇卡 JSON 結構：**
```json
{
  "id": "encounter_amnesia",
  "name": "失憶詛咒",
  "type": "encounter",
  "subtype": "treachery",
  "rarity": "common",
  "description": "一股黑暗力量侵蝕了你的記憶...",
  "flavor": "「我剛才在想什麼來著？」",
  "revelation": {
    "kind": "discard_hand",
    "keep_count": 1
  },
  "traits": ["詛咒", "精神"]
}
```

**Revelation 效果類型：**
- `discard_hand` - 棄掉手牌保留指定數量
- `damage_hp` - 直接扣血
- `damage_sanity` - 直接扣理智
- `damage_both` - 同時扣血和理智
- `discard_resource` - 損失資源
- `damage_equipment` - 損壞裝備
- `spawn_enemy` - 生成敵人（需戰鬥）
- `add_doom` - 增加末日值
- `curse` - 下回合行動點減少

---

## 🎴 2. 遭遇牌組管理（card_manager.gd 擴充）

在 `CardManager` 中新增：
- `encounter_deck: Array[String]` - 遭遇牌組
- `encounter_discard: Array[String]` - 遭遇棄牌堆
- `init_encounter_deck()` - 根據當前地點初始化遭遇牌組
- `draw_encounter_card()` - 抽一張遭遇卡並觸發 Revelation
- `reshuffle_encounter_discard()` - 重置遭遇牌組

**新信號：**
- `encounter_drawn(card_data)` - 抽到遭遇卡時觸發
- `encounter_deck_updated(count)` - 遭遇牌組數量更新
- `doom_updated(value)` - 末日值更新

---

## ⏰ 3. 末日/腐化計量表（Doom System）

- **末日值**：初始 0，上限 10
- **末日增加時機**：
  - 每回合結束 +1
  - 移動到新地點 +1
  - 某些遭遇卡效果 +1~2
- **末日閾值事件**：
  - 末日 3：抽 1 張遭遇卡
  - 末日 5：抽 2 張遭遇卡
  - 末日 7：所有遭遇卡效果翻倍
  - 末日 10：遊戲結束（Bad Ending）

---

## 🎲 4. 命運袋系統（Chaos Bag / Fate Bag）

- **命運袋**：包含 10 個 token
- **token 類型**：
  - `+1`, `0`, `-1`, `-2`, `-3` - 修正值
  - `skull` - 骷髏（大失敗）
  - `elder_sign` - 古老印記（大成功）
- **使用時機**：
  - 遭遇卡 Revelation 檢定
  - 解鎖/調查檢定
  - 戰鬥檢定

---

## 🔄 5. 與地圖系統整合（map.gd 擴充）

- **移動到新地點時**：自動抽 1 張遭遇卡
- **每回合結束時**：末日值 +1，檢查閾值
- **遭遇卡 Revelation 執行**：顯示對話框 + 執行效果
- **敵人遭遇**：進入戰鬥模式（簡化版）
- **UI 顯示**：
  - 末日計量表（螢幕上方）
  - 遭遇牌組剩餘數量
  - 命運袋剩餘 token

---

## 📋 實作步驟

1. **cards.json** - 新增 15 張遭遇卡資料
2. **card_manager.gd** - 新增遭遇牌組管理 + 末日系統 + 命運袋
3. **encounter_manager.gd** - 新增獨立的遭遇管理器腳本（處理 Revelation 效果執行）
4. **map.gd** - 整合遭遇系統到地圖探索流程
5. **UI 元件** - 末日計量表 UI + 遭遇卡揭示動畫
6. **Godot 語法檢查** - 確保無錯誤
