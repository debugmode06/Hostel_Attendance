
# ==============================================================================
# HUGGING FACE SPACE CODE (app.py)
# Deploy this to your Hugging Face Space (SDK: Docker or Streamlit/Gradio, 
# but preferably Docker with FastAPI for performance).
# 
# Recommended: specific Dockerfile with PyTorch + FastAPI
# ==============================================================================

import os
import io
import torch
import numpy as np
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
from facenet_pytorch import MTCNN, InceptionResnetV1

app = FastAPI()

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ------------------------------------------------------------------------------
# 1. MODEL INITIALIZATION (Warm-up)
# Load models ONCE at startup, not per request
# ------------------------------------------------------------------------------
device = torch.device('cpu') # Force CPU for free tier stability
print(f"Running on device: {device}")

print("Loading MTCNN...")
# keep_all=False means just return the best face
mtcnn = MTCNN(
    image_size=160, 
    margin=0, 
    min_face_size=20, 
    thresholds=[0.6, 0.7, 0.7], 
    factor=0.709, 
    post_process=True,
    device=device
)

print("Loading InceptionResnetV1...")
resnet = InceptionResnetV1(pretrained='vggface2').eval().to(device)

print("Model loaded successfully!")

# ------------------------------------------------------------------------------
# 2. HELPER FUNCTIONS
# ------------------------------------------------------------------------------
def normalize_l2(x):
    """Normalize vector to unit length (L2 norm)"""
    x = np.array(x)
    norm = np.linalg.norm(x)
    if norm == 0: 
        return x
    return x / norm

def process_image(image_bytes):
    """Convert bytes to PIL Image"""
    try:
        image = Image.open(io.BytesIO(image_bytes))
        if image.mode != 'RGB':
            image = image.convert('RGB')
        return image
    except Exception as e:
        print(f"Image load error: {e}")
        return None

# ------------------------------------------------------------------------------
# 3. ENDPOINTS
# ------------------------------------------------------------------------------

@app.get("/")
def home():
    return {"status": "running", "message": "Face Recognition API is Active"}

@app.get("/health")
def health():
    # Simple health check that ensures models are in memory
    if mtcnn is None or resnet is None:
        raise HTTPException(status_code=503, detail="Models not loaded")
    return {"status": "ok"}

@app.post("/register")
async def register(image: UploadFile = File(...), regNo: str = "unknown"):
    """
    Receives an image, detects face, computes embedding.
    Returns: { "embedding": [float, ...], "regNo": ... }
    """
    try:
        contents = await image.read()
        pil_image = process_image(contents)
        
        if pil_image is None:
            raise HTTPException(status_code=400, detail="Invalid image file")

        # Detect face
        # return_prob=True if we want confidence, but we just need the aligned face tensor
        img_cropped = mtcnn(pil_image) 

        if img_cropped is None:
            return {"message": "No face detected", "embedding": []}

        # Calculate embedding
        with torch.no_grad():
            img_embedding = resnet(img_cropped.unsqueeze(0)).numpy()[0]
        
        # Normalize
        normalized_embedding = normalize_l2(img_embedding).tolist()

        return {
            "regNo": regNo,
            "embedding": normalized_embedding,
            "message": "Face processed successfully"
        }

    except Exception as e:
        print(f"Error processing {regNo}: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/verify")
async def verify(image: UploadFile = File(...)):
    """
    Same as register, but semantically for verification. 
    Returns embedding to be compared on the backend.
    """
    return await register(image, "TEMP_VERIFY")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7860)
