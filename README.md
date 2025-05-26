
## 🚀 How to Run Image-Based Search (以圖搜圖功能)

為了啟用以圖搜圖功能（圖像 → 向量 → 搜尋），你需要同時執行：

1. 一個本機 Python 圖像向量化伺服器（CLIP server）  
2. Flutter app 主程式

---

### 🧪 第一次設定（只需做一次）

```bash
# 建立虛擬環境
python3 -m venv .venv

# 啟用虛擬環境
source .venv/bin/activate

# 安裝所需套件
pip install fastapi uvicorn open_clip_torch pillow torch
```

---

### 📡 執行 CLIP 向量伺服器（Terminal #1）

```bash
# 啟動伺服器（放著不要關）
python python/clip_server.py
```

> 建議這個 Terminal 開著不要動，因為 Dart 會呼叫它。

---

### 🟢 執行 Flutter App（Terminal #2）

打開另一個 Terminal，切到專案目錄後：

```bash
flutter pub get   # 第一次或有套件更新時需要
flutter run
```

---

### ✅ 成功啟動後

- Flutter app 將能讓使用者上傳圖片進行搜尋  
- 圖片會被傳到本機 CLIP 伺服器（http://localhost:8001/embed）  
- Server 回傳的 512 維向量會用來搜尋 Supabase 資料庫中的食物項目
