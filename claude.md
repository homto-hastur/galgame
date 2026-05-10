# 全局指令與行為準則 (Global Rules)

1. **始終使用繁體中文回答**：
   在任何情況下，與使用者對話、解釋概念、總結進度或是詢問問題時，都必須使用繁體中文 (Traditional Chinese)。
   
   *Always respond to the user in Traditional Chinese for any conversation, explanation, progress summary, or questions.*

2. **用戶絕對正確原則**：
   如果某個功能被用戶提及，且經過多次嘗試後用戶表示無法解決，則默認用戶是絕對正確的。此時應：
   1. 把整個功能取消/還原
   2. 重新嘗試以不同方式添加該功能
   
   *If a feature is requested by the user and after multiple attempts the user indicates it cannot be resolved, default to the user being absolutely correct. In this case: 1) Cancel/revert the entire feature, 2) Re-attempt adding the feature using a different approach.*

3. **任務完成通知**：
   每次完成任務（使用 attempt_completion）時，請執行以下命令來觸發系統通知，提醒用戶打開 Cursor：
   ```
   "c:\ai\notify_cursor.bat"
   ```
   這會在 Windows 右下角彈出氣泡通知：「任務已完成！請打開 Cursor 繼續工作。」
   
   *When completing a task (using attempt_completion), execute the above command to trigger a system notification reminding the user to open Cursor.*

4. **🚫 禁止未經授權的 Git/GitHub 操作**：
   除非用戶明確下達備份指令（例如「推送到 GitHub」、「commit」、「備份」、「push」等），否則嚴格禁止執行任何 Git 操作，包括但不限於：
   - `git add`、`git commit`、`git push`
   - `git init`、`git remote` 等倉庫設定操作
   - 使用用戶的 GitHub 帳號進行任何遠端操作
   - 將檔案上傳到任何遠端倉庫
   
   所有開發工作僅限於本地檔案修改，由用戶自行決定何時進行版本控制備份。
   若用戶未明確授權但需要 Git 操作來完成任務，必須先詢問用戶取得許可。
   
   *Unless the user explicitly gives backup instructions (e.g., "push to GitHub", "commit", "backup", "push"), strictly prohibit any Git operations including but not limited to: git add, git commit, git push, git init, git remote setup, using the user's GitHub account for any remote operations, or uploading files to any remote repository. All development work is limited to local file modifications only. If Git operations are needed but not explicitly authorized, ask the user for permission first.*


