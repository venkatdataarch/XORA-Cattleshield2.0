"""
Muzzle Biometric Engine using ResNet-50 ONNX for embedding extraction.

Generates 1000-dim embeddings from muzzle images, then compares using
cosine similarity for animal identification and verification.

Separate processing pipelines for:
- COW/BUFFALO: Nasal ridge pattern (unique fingerprint-like ridges)
- MULE/HORSE: Nose+lip texture (different pattern structure)
"""

import os
import logging
import numpy as np
from PIL import Image, ImageFilter, ImageEnhance
import onnxruntime as ort

logger = logging.getLogger(__name__)

# Singleton model session
_session: ort.InferenceSession | None = None
_input_name: str = ""
_output_name: str = ""

MODEL_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
    "models",
    "resnet50.onnx",
)

EMBEDDING_DIM = 1000  # ResNet-50 output dimension


def _get_session() -> ort.InferenceSession:
    """Lazy-load the ONNX model session (singleton)."""
    global _session, _input_name, _output_name

    if _session is None:
        if not os.path.exists(MODEL_PATH):
            raise FileNotFoundError(
                f"ResNet-50 ONNX model not found at {MODEL_PATH}. "
                "Download it first."
            )
        logger.info(f"Loading ResNet-50 ONNX model from {MODEL_PATH}")
        _session = ort.InferenceSession(
            MODEL_PATH,
            providers=["CPUExecutionProvider"],
        )
        _input_name = _session.get_inputs()[0].name
        _output_name = _session.get_outputs()[0].name
        logger.info(
            f"Model loaded. Input: {_input_name}, Output: {_output_name}"
        )

    return _session


def preprocess_cow_muzzle(image: Image.Image) -> np.ndarray:
    """
    Preprocess cow/buffalo muzzle image for CNN embedding.

    Cow muzzles have unique ridge patterns (like human fingerprints).
    Apply CLAHE-like contrast enhancement to highlight ridges.
    """
    # Convert to RGB
    img = image.convert("RGB")

    # Crop center 80% (focus on muzzle, remove background)
    w, h = img.size
    crop_margin_w = int(w * 0.1)
    crop_margin_h = int(h * 0.1)
    img = img.crop((crop_margin_w, crop_margin_h, w - crop_margin_w, h - crop_margin_h))

    # Resize to 224x224 (ResNet input size)
    img = img.resize((224, 224), Image.LANCZOS)

    # Enhance contrast to highlight ridge patterns
    enhancer = ImageEnhance.Contrast(img)
    img = enhancer.enhance(1.5)

    # Sharpen to bring out ridge details
    img = img.filter(ImageFilter.SHARPEN)

    # Convert to numpy and normalize (ImageNet mean/std)
    arr = np.array(img, dtype=np.float32) / 255.0
    mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
    arr = (arr - mean) / std

    # Transpose to NCHW format (batch, channels, height, width)
    arr = arr.transpose(2, 0, 1)
    arr = np.expand_dims(arr, axis=0)

    return arr


def preprocess_mule_muzzle(image: Image.Image) -> np.ndarray:
    """
    Preprocess mule/horse muzzle image for CNN embedding.

    Mule/horse muzzles have different texture — wider nostrils,
    smoother patterns. Preserve color information more.
    """
    img = image.convert("RGB")

    # Less aggressive crop (mule muzzle is wider)
    w, h = img.size
    crop_margin_w = int(w * 0.05)
    crop_margin_h = int(h * 0.05)
    img = img.crop((crop_margin_w, crop_margin_h, w - crop_margin_w, h - crop_margin_h))

    # Resize
    img = img.resize((224, 224), Image.LANCZOS)

    # Lighter contrast enhancement (preserve natural color)
    enhancer = ImageEnhance.Contrast(img)
    img = enhancer.enhance(1.2)

    # Convert and normalize
    arr = np.array(img, dtype=np.float32) / 255.0
    mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
    arr = (arr - mean) / std
    arr = arr.transpose(2, 0, 1)
    arr = np.expand_dims(arr, axis=0)

    return arr


def extract_embedding(image_bytes: bytes, species: str = "cow") -> np.ndarray:
    """
    Extract a 1000-dim embedding vector from a muzzle image.

    Args:
        image_bytes: Raw image bytes (JPEG/PNG)
        species: "cow", "buffalo", "mule", "horse"

    Returns:
        1D numpy array of shape (1000,) — the muzzle embedding
    """
    import io
    img = Image.open(io.BytesIO(image_bytes))

    # Species-specific preprocessing
    species_lower = species.lower().strip()
    if species_lower in ("cow", "buffalo", "cattle", "bovine"):
        input_tensor = preprocess_cow_muzzle(img)
    else:
        input_tensor = preprocess_mule_muzzle(img)

    # Run inference
    session = _get_session()
    outputs = session.run([_output_name], {_input_name: input_tensor})

    # Get embedding (1000-dim vector)
    embedding = outputs[0].flatten()

    # L2 normalize for cosine similarity
    norm = np.linalg.norm(embedding)
    if norm > 0:
        embedding = embedding / norm

    return embedding


def cosine_similarity(emb1: np.ndarray, emb2: np.ndarray) -> float:
    """
    Compute cosine similarity between two embedding vectors.

    Returns value between -1 and 1 (higher = more similar).
    For muzzle matching, >0.7 is typically a match.
    """
    # Embeddings should already be L2-normalized
    similarity = float(np.dot(emb1, emb2))
    return similarity


def compare_muzzles(
    image1_bytes: bytes,
    image2_bytes: bytes,
    species: str = "cow",
) -> dict:
    """
    Compare two muzzle images and return similarity score.

    Returns dict with:
    - similarity_score: 0.0 to 1.0
    - match_confidence: "high", "medium", "low"
    - is_match: bool
    """
    emb1 = extract_embedding(image1_bytes, species)
    emb2 = extract_embedding(image2_bytes, species)

    similarity = cosine_similarity(emb1, emb2)

    # Convert to 0-100 scale
    score_pct = max(0, min(100, (similarity + 1) * 50))  # Map [-1,1] to [0,100]

    if score_pct >= 80:
        confidence = "high"
        is_match = True
    elif score_pct >= 60:
        confidence = "medium"
        is_match = True
    else:
        confidence = "low"
        is_match = False

    return {
        "similarity_score": round(score_pct, 2),
        "raw_cosine": round(similarity, 6),
        "match_confidence": confidence,
        "is_match": is_match,
        "embedding_dim": EMBEDDING_DIM,
        "model": "ResNet-50-ONNX",
        "species_pipeline": species,
    }


def embedding_to_list(embedding: np.ndarray) -> list[float]:
    """Convert numpy embedding to JSON-serializable list."""
    return [round(float(x), 8) for x in embedding]


def list_to_embedding(data: list[float]) -> np.ndarray:
    """Convert stored list back to numpy embedding."""
    return np.array(data, dtype=np.float32)
