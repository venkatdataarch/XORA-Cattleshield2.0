import os
import uuid
import aiofiles
from fastapi import UploadFile

from ..config import get_settings

settings = get_settings()


async def save_upload(file: UploadFile, subfolder: str = "") -> str:
    upload_dir = os.path.join(settings.upload_dir, subfolder)
    os.makedirs(upload_dir, exist_ok=True)

    ext = os.path.splitext(file.filename or "file")[1] or ".jpg"
    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = os.path.join(upload_dir, filename)

    async with aiofiles.open(filepath, "wb") as f:
        content = await file.read()
        await f.write(content)

    return f"/uploads/{subfolder}/{filename}" if subfolder else f"/uploads/{filename}"
