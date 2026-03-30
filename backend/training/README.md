# Muzzle Recognition Model Training (Phase 2)

## Quick Start

### Option 1: Google Colab (Free GPU)

1. Upload `train_muzzle_model.py` to Google Drive
2. Open Google Colab: https://colab.research.google.com
3. Run:
```python
# Mount Google Drive
from google.colab import drive
drive.mount('/content/drive')

# Install dependencies
!pip install torch torchvision pillow tqdm onnxruntime

# Upload your dataset to Drive under /dataset/cow/animal_xxx/
# Then train:
!python /content/drive/MyDrive/train_muzzle_model.py \
  --data_dir /content/drive/MyDrive/dataset \
  --species cow \
  --epochs 100 \
  --batch_size 32 \
  --output_dir /content/drive/MyDrive/trained_models
```

### Option 2: Local Training (GPU required)

```bash
pip install torch torchvision pillow tqdm onnxruntime

python train_muzzle_model.py \
  --data_dir ./dataset \
  --species cow \
  --epochs 100 \
  --batch_size 16
```

## Dataset Structure

```
dataset/
  cow/
    animal_001/
      front_1.jpg
      front_2.jpg
      left_1.jpg
      right_1.jpg
      ...  (minimum 2 images per animal)
    animal_002/
      ...
  mule/
    animal_501/
      ...
```

**Minimum requirements:**
- 500+ animals
- 2+ images per animal (10+ recommended)
- Total: 5,000+ images

## After Training

1. The trained ONNX model is saved to `trained_models/muzzle_cow_v2.onnx`
2. Copy it to `backend/models/` replacing `resnet50.onnx`
3. Update `backend/app/ai/muzzle_engine.py` — change `EMBEDDING_DIM = 512`
4. Restart the backend server

## Evaluate

```bash
python train_muzzle_model.py \
  --evaluate \
  --checkpoint trained_models/best_model.pth \
  --data_dir ./dataset \
  --species cow
```

## Expected Results

| Phase | Dataset Size | Accuracy |
|-------|-------------|----------|
| Phase 1 (current) | Pre-trained only | 90-95% |
| Phase 2 (this script) | 5,000 images | 95-97% |
| Phase 2 + more data | 20,000 images | 97-99% |
