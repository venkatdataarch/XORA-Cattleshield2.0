import os
import uuid
import hashlib
from datetime import datetime

import aiofiles
from fastapi import UploadFile

from ..config import get_settings

settings = get_settings()


async def save_upload(file: UploadFile, subfolder: str = "") -> str:
    """Save a generic upload file."""
    upload_dir = os.path.join(settings.upload_dir, subfolder)
    os.makedirs(upload_dir, exist_ok=True)

    ext = os.path.splitext(file.filename or "file")[1] or ".jpg"
    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = os.path.join(upload_dir, filename)

    async with aiofiles.open(filepath, "wb") as f:
        content = await file.read()
        await f.write(content)

    return f"/uploads/{subfolder}/{filename}" if subfolder else f"/uploads/{filename}"


async def save_muzzle_scan(
    image_bytes: bytes,
    species: str,
    animal_id: str,
    angle: str,
) -> dict:
    """
    Save a muzzle scan image in species/animal structured folder.

    Structure:
      uploads/muzzle_scans/{species}/{animal_id}/{angle}_{timestamp}.jpg

    Returns metadata dict with path, hash, timestamp.
    """
    species_key = species.lower().strip()
    if species_key in ("cow", "cattle", "bovine"):
        species_folder = "cow"
    elif species_key == "buffalo":
        species_folder = "buffalo"
    else:
        species_folder = "mule"

    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S_%f")
    folder = os.path.join(settings.upload_dir, "muzzle_scans", species_folder, animal_id)
    os.makedirs(folder, exist_ok=True)

    filename = f"{angle}_{timestamp}.jpg"
    filepath = os.path.join(folder, filename)

    # Calculate SHA-256 hash before saving
    sha256_hash = hashlib.sha256(image_bytes).hexdigest()

    async with aiofiles.open(filepath, "wb") as f:
        await f.write(image_bytes)

    relative_path = f"/uploads/muzzle_scans/{species_folder}/{animal_id}/{filename}"

    return {
        "path": relative_path,
        "filename": filename,
        "angle": angle,
        "species": species_folder,
        "animal_id": animal_id,
        "sha256_hash": sha256_hash,
        "timestamp": datetime.utcnow().isoformat(),
        "size_bytes": len(image_bytes),
    }


async def save_health_photo(
    image_bytes: bytes,
    animal_id: str,
    slot_name: str,
) -> dict:
    """
    Save a health assessment photo in animal-specific folder.

    Structure:
      uploads/health_photos/{animal_id}/{slot}_{timestamp}.jpg
    """
    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S_%f")
    folder = os.path.join(settings.upload_dir, "health_photos", animal_id)
    os.makedirs(folder, exist_ok=True)

    filename = f"{slot_name}_{timestamp}.jpg"
    filepath = os.path.join(folder, filename)

    sha256_hash = hashlib.sha256(image_bytes).hexdigest()

    async with aiofiles.open(filepath, "wb") as f:
        await f.write(image_bytes)

    return {
        "path": f"/uploads/health_photos/{animal_id}/{filename}",
        "filename": filename,
        "slot": slot_name,
        "animal_id": animal_id,
        "sha256_hash": sha256_hash,
        "timestamp": datetime.utcnow().isoformat(),
        "size_bytes": len(image_bytes),
    }


async def save_claim_evidence(
    image_bytes: bytes,
    claim_id: str,
    evidence_type: str,
) -> dict:
    """
    Save claim evidence in claim-specific folder.

    Structure:
      uploads/claim_evidence/{claim_id}/{type}_{timestamp}.jpg
    """
    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S_%f")
    folder = os.path.join(settings.upload_dir, "claim_evidence", claim_id)
    os.makedirs(folder, exist_ok=True)

    filename = f"{evidence_type}_{timestamp}.jpg"
    filepath = os.path.join(folder, filename)

    sha256_hash = hashlib.sha256(image_bytes).hexdigest()

    async with aiofiles.open(filepath, "wb") as f:
        await f.write(image_bytes)

    return {
        "path": f"/uploads/claim_evidence/{claim_id}/{filename}",
        "filename": filename,
        "evidence_type": evidence_type,
        "claim_id": claim_id,
        "sha256_hash": sha256_hash,
        "timestamp": datetime.utcnow().isoformat(),
        "size_bytes": len(image_bytes),
    }


async def save_body_photo(
    image_bytes: bytes,
    animal_id: str,
    angle: str,
) -> dict:
    """
    Save 360-degree body photo in animal-specific folder.

    Structure:
      uploads/body_photos/{animal_id}/{angle}_{timestamp}.jpg
    """
    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S_%f")
    folder = os.path.join(settings.upload_dir, "body_photos", animal_id)
    os.makedirs(folder, exist_ok=True)

    filename = f"{angle}_{timestamp}.jpg"
    filepath = os.path.join(folder, filename)

    sha256_hash = hashlib.sha256(image_bytes).hexdigest()

    async with aiofiles.open(filepath, "wb") as f:
        await f.write(image_bytes)

    return {
        "path": f"/uploads/body_photos/{animal_id}/{filename}",
        "filename": filename,
        "angle": angle,
        "animal_id": animal_id,
        "sha256_hash": sha256_hash,
        "timestamp": datetime.utcnow().isoformat(),
        "size_bytes": len(image_bytes),
    }


def get_animal_folder(animal_id: str, category: str = "muzzle_scans", species: str = "cow") -> str:
    """Get the folder path for an animal's images."""
    if category == "muzzle_scans":
        return os.path.join(settings.upload_dir, category, species, animal_id)
    return os.path.join(settings.upload_dir, category, animal_id)


def list_animal_images(animal_id: str, category: str = "muzzle_scans", species: str = "cow") -> list:
    """List all images for an animal in a given category."""
    folder = get_animal_folder(animal_id, category, species)
    if not os.path.exists(folder):
        return []
    return sorted([
        f"/uploads/{category}/{species}/{animal_id}/{f}" if category == "muzzle_scans"
        else f"/uploads/{category}/{animal_id}/{f}"
        for f in os.listdir(folder)
        if f.lower().endswith(('.jpg', '.jpeg', '.png'))
    ])
