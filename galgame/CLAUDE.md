# 專案規則

任何情景下，先假設我在用 Godot 進行工作。

## 🚫 Git/GitHub 備份規則（嚴格禁止未經授權的操作）

除非用戶明確下達備份指令（例如「推送到 GitHub」、「commit」、「備份」、「push」等），否則嚴格禁止執行任何 Git 操作，包括但不限於：
1. `git add`、`git commit`、`git push`
2. `git init`、`git remote` 等倉庫設定操作
3. 使用用戶的 GitHub 帳號進行任何遠端操作
4. 將檔案上傳到任何遠端倉庫

所有開發工作僅限於本地檔案修改，由用戶自行決定何時進行版本控制備份。
若用戶未明確授權但需要 Git 操作來完成任務，必須先詢問用戶取得許可。

## 運行驗證規則

在報告給用戶前，必須先運行專案一次：
1. 使用 `--check-only` 參數運行 Godot 專案
2. 檢查 stderr 輸出是否有 SCRIPT ERROR
3. 如果有錯誤，修復後重新運行，直到順利運行一次為止（無 SCRIPT ERROR）
4. 確認無誤後再通知用戶

## 用戶絕對正確原則

如果某個功能被用戶提及，且經過多次嘗試後用戶表示無法解決，則默認用戶是絕對正確的。此時應：
1. 把整個功能取消/還原
2. 重新嘗試以不同方式添加該功能



當我需要涉及卡牌、基礎玩法、遊戲等內容時，先參考 arkhamhorror 中的內容。

## 首先參考 'ArkhamHorror'

當需要設計遊戲機制、數值系統、UI 佈局或任何與遊戲玩法相關的內容時，優先參考 `ArkhamHorror/` 目錄中的內容：

### 專案結構
```
ArkhamHorror/
├── docker-compose.yml    # Docker 容器配置（PostgreSQL + Web + Nginx）
├── nginx.conf            # Nginx 反向代理配置（卡圖 CDN 快取）
├── setup.sql             # 資料庫表結構（users, games, decks, players, steps, logs）
├── setup.bat             # 首次安裝腳本
├── start.bat             # 啟動伺服器
├── stop.bat              # 停止伺服器
├── kill3000.bat          # 強制釋放 port 3000
├── frontend/             # 前端靜態檔案
│   └── public/
│       ├── img/          # 卡圖資源（arkham/zh/cards/ 中文, arkham/cards/ 英文）
│       ├── index.html    # 前端入口
│       └── assets/       # 前端打包資源
└── overrides/
    └── cards_zh.json     # 中文卡牌名稱覆蓋
```

### 核心設計參考

1. **數值系統**：參考 Arkham Horror LCG 的調查員數值體系
   - 生命值（HP）和理智值（Sanity）作為角色核心狀態
   - 四維能力：意志力（Willpower）、智力（Intellect）、戰鬥（Combat）、敏捷（Agility），範圍 1~5
   - 每回合 3 次行動（Actions）

2. **地點系統**：參考 Arkham Horror 的地點連接機制
   - 地點之間有連接關係（connections）
   - 迷霧值（Shroud）和線索（Clues）機制
   - 地點鎖定/解鎖狀態

3. **UI 佈局**：參考 Arkham Horror LCG 的 UI 風格
   - 角色狀態面板在左側
   - 行動次數以十字架圖示顯示
   - 資訊面板使用白色背景 + 邊框

4. **卡牌機制**：參考 Arkham Horror 的卡牌系統
   - 卡牌分為不同類型（技能、事件、資產等）
   - 卡牌消耗資源（資源、行動、線索等）
   - 卡牌效果涉及檢定（技能測試）

## 精靈圖（Sprite Sheet）規範

### 格式要求
- **格式**：PNG（支援透明背景 RGBA）
- **每幀尺寸**：115 × 115 像素（整數，避免剪裁偏移）
- **中心點**：每幀中心在 (57.5, 57.5)

### 每行10幀的4種姿勢變化
- 第1幀 → 起始姿勢
- 第2-4幀 → 變化A（過渡動作）
- 第5-7幀 → 變化B（另一種過渡動作）
- 第8-10幀 → 回到起始姿勢

### 提示詞模板（中文）
```
像素風遊戲角色精靈圖，[角色描述]，Sprite Sheet，[行數]行[列數]列網格排列

[逐行描述每行的動作內容]

每行10幀循環動畫：第1幀起始姿勢 → 第2-4幀第一種過渡 → 第5-7幀第二種過渡 → 第8-10幀回到起始姿勢

每個角色大小約80x80像素，透明背景，黑色輪廓線條，復古RPG風格，16位元色彩
```

### Godot 實作方式
- 使用 `Sprite2D` + `region_enabled = true`
- 用 `region_rect = Rect2(x, y, 115, 115)` 切換幀
- Sprite2D 位置設為 (64, 64) 在 128x128 的 Control 中居中
- 動畫速度：0.1 秒/幀
- 移動完成後自動回到 idle 第0幀
