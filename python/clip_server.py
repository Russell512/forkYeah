# python/clip_server.py
import io, torch, uvicorn
from fastapi import FastAPI, File, UploadFile
from PIL import Image
import open_clip

# ---- 選 GPU (MPS) or CPU --------------------------------------------------
if torch.backends.mps.is_available():
    device = "mps"
elif torch.cuda.is_available():
    device = "cuda"
else:
    device = "cpu"

# ---- 載模型 ---------------------------------------------------------------
model, _, preprocess = open_clip.create_model_and_transforms(
    "ViT-B-32", pretrained="openai"
)
model = model.to(device).float().eval()
torch.set_default_dtype(torch.float32)

# ---- FastAPI --------------------------------------------------------------
app = FastAPI()

def img_to_tensor(img_bytes: bytes):
    img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
    return preprocess(img).unsqueeze(0).to(device)

@app.post("/embed")
async def embed(file: UploadFile = File(...)):
    img_bytes = await file.read()
    with torch.no_grad():
        tensor = img_to_tensor(img_bytes)
        emb = model.encode_image(tensor).squeeze(0)
        emb = emb / emb.norm()               # cosine normalize
    return {"embedding": emb.cpu().tolist()}  # List[512]

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)
