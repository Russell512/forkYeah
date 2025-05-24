# 🥢 ForkYeah 專案協作流程指南

本專案採用 Flutter + GitHub 協作開發，以下記錄從開發到上線的完整步驟流程。

---

## 🛠️ 開始開發

1. **切換或建立新分支**
   ```bash
   git checkout -b feat/login-page
   ```
   分支命名慣例（請遵守）：
   - 新功能：`feat/xxx`
   - 修 bug：`fix/xxx`
   - 雜項更新：`chore/xxx`

2. **撰寫功能程式碼**
   - Flutter UI 使用 `material.dart`
   - 開發完成後請在模擬器中測試：
     ```bash
     flutter run
     ```

---

## 🔄 本地端提交

3. **確認變更並提交**
   ```bash
   git status
   git add .
   git commit -m "feat: create login page"
   ```

4. **推送到 GitHub 遠端分支**
   ```bash
   git push origin feat/login-page
   ```

---

## 🔍 建立 PR（Pull Request）

5. 前往 GitHub，點選「Compare & pull request」

6. 填寫 PR 標題與描述，例如：
   ```
   feat: 建立登入頁
   初步完成登入畫面 UI，尚未連接後端。
   ```

7. 指定 Reviewer（若有組員請 tag 他們）

---

## ✅ Review + Merge

8. **請組員檢查 PR**
   - 若需修改，請根據留言進行調整並再次 commit
   - 若通過，Review 人員點選「Approve」

9. **Merge PR**
   - 點選「Merge pull request」
   - 刪除已合併分支（可選）

10. **拉取最新主線分支**
    ```bash
    git checkout main
    git pull origin main
    ```

---

## 🧼 補充指令

- **清除 build cache（遇錯用）**
  ```bash
  flutter clean
  flutter pub get
  flutter run
  ```

- **查看裝置與模擬器**
  ```bash
  flutter devices
  flutter emulators
  ```

---

👩‍💻 協作愉快，一起打造 ForkYeah ✨