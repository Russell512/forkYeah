
## How to run
為了能實現以圖搜圖
要跑這個程式要先
python3 -m venv .venv
然後啟用虛擬環境
source .venv/bin/activate
安裝要的套件
pip install fastapi uvicorn open_clip_torch pillow torch
然後跑
python python/clip_server.py (這個就放在一個terminal裡面 然後新開一個terminal)
-
另外一個terminal第一次要輸入flutter pub get
然後再flutter run
