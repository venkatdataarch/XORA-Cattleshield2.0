"""
FAISS-powered muzzle matching engine.
Uses ResNet-50 ONNX embeddings + FAISS cosine similarity search.

Registration: Extract embedding → Add to FAISS index
Identification: Extract embedding → Search FAISS → Return top matches
"""

import os
import json
import numpy as np
import faiss
from pathlib import Path
from datetime import datetime, timezone, timedelta

from .muzzle_engine import extract_embedding as _extract_embedding

IST = timezone(timedelta(hours=5, minutes=30))

# Directory to store FAISS index
INDEX_DIR = Path(__file__).parent.parent.parent / "faiss_data"
INDEX_DIR.mkdir(exist_ok=True)

COW_INDEX_PATH = INDEX_DIR / "cow_muzzle.index"
MULE_INDEX_PATH = INDEX_DIR / "mule_muzzle.index"
METADATA_PATH = INDEX_DIR / "metadata.json"


class FAISSMuzzleMatcher:
    """
    FAISS-based muzzle matching system.

    - Uses ResNet-50 ONNX for embedding extraction (1000-dim, L2-normalized)
    - FAISS IndexFlatIP for cosine similarity (inner product on normalized vectors)
    - Separate indices for cow and mule species
    - Metadata stored alongside for animal_id mapping
    """

    def __init__(self):
        self.embedding_dim = 1000  # ResNet-50 output dimension

        # Separate FAISS indices for cow and mule
        self.cow_index = None
        self.mule_index = None

        # Metadata: maps FAISS row index → {animal_id, species, registered_at, image_path}
        self.metadata = {"cow": [], "mule": []}

        self._load_indices()

    def _extract(self, image_path: str, species: str) -> np.ndarray | None:
        """Extract embedding from image file using ResNet-50 ONNX."""
        try:
            with open(image_path, "rb") as f:
                image_bytes = f.read()
            return _extract_embedding(image_bytes, species=species)
        except Exception as e:
            print(f"Embedding extraction error: {e}")
            return None

    def _load_indices(self):
        """Load existing FAISS indices and metadata from disk."""
        # Load cow index
        if COW_INDEX_PATH.exists():
            self.cow_index = faiss.read_index(str(COW_INDEX_PATH))
        else:
            # Create new IndexFlatIP (Inner Product = cosine similarity on L2-normalized vectors)
            self.cow_index = faiss.IndexFlatIP(self.embedding_dim)

        # Load mule index
        if MULE_INDEX_PATH.exists():
            self.mule_index = faiss.read_index(str(MULE_INDEX_PATH))
        else:
            self.mule_index = faiss.IndexFlatIP(self.embedding_dim)

        # Load metadata
        if METADATA_PATH.exists():
            with open(METADATA_PATH, "r") as f:
                self.metadata = json.load(f)

    def _save_indices(self):
        """Persist FAISS indices and metadata to disk."""
        faiss.write_index(self.cow_index, str(COW_INDEX_PATH))
        faiss.write_index(self.mule_index, str(MULE_INDEX_PATH))
        with open(METADATA_PATH, "w") as f:
            json.dump(self.metadata, f, indent=2)

    def _get_index(self, species: str):
        """Get the appropriate FAISS index for the species."""
        if species in ("cow", "buffalo"):
            return self.cow_index, "cow"
        else:
            return self.mule_index, "mule"

    def register_muzzle(
        self,
        image_path: str,
        animal_id: str,
        species: str,
        angle: str = "front"
    ) -> dict:
        """
        Register a muzzle image in the FAISS index.

        Args:
            image_path: Path to the muzzle image file
            animal_id: Unique animal identifier
            species: "cow", "buffalo", "mule", "horse"
            angle: "front", "left", "right"

        Returns:
            dict with embedding_id, similarity check results
        """
        # Extract embedding using ResNet-50 ONNX
        embedding = self._extract(image_path, species)

        if embedding is None:
            return {
                "success": False,
                "error": "Failed to extract muzzle embedding",
                "animal_id": animal_id
            }

        # L2 normalize for cosine similarity
        embedding = embedding / (np.linalg.norm(embedding) + 1e-8)
        embedding = embedding.reshape(1, -1).astype(np.float32)

        # Check for duplicates before adding
        index, species_key = self._get_index(species)
        duplicate_check = self._check_duplicate(embedding, species_key)

        # Add to FAISS index
        index.add(embedding)

        # Store metadata
        self.metadata[species_key].append({
            "animal_id": animal_id,
            "species": species,
            "angle": angle,
            "image_path": image_path,
            "registered_at": datetime.now(IST).isoformat(),
            "faiss_idx": index.ntotal - 1
        })

        # Save to disk
        self._save_indices()

        result = {
            "success": True,
            "animal_id": animal_id,
            "species": species,
            "embedding_dim": self.embedding_dim,
            "index_size": index.ntotal,
            "registered_at": datetime.now(IST).isoformat()
        }

        # Include duplicate warning if found
        if duplicate_check and duplicate_check["similarity"] > 0.85:
            result["duplicate_warning"] = {
                "matched_animal_id": duplicate_check["animal_id"],
                "similarity": round(duplicate_check["similarity"] * 100, 2),
                "message": f"Possible duplicate — {duplicate_check['similarity']*100:.1f}% match with existing animal"
            }

        return result

    def identify_muzzle(
        self,
        image_path: str,
        species: str,
        top_k: int = 5
    ) -> dict:
        """
        Identify an animal by muzzle scan.
        Searches FAISS index for nearest matches.

        Args:
            image_path: Path to the query muzzle image
            species: "cow", "buffalo", "mule", "horse"
            top_k: Number of top matches to return

        Returns:
            dict with matches list, each containing animal_id, similarity score
        """
        # Extract embedding
        embedding = self._extract(image_path, species)

        if embedding is None:
            return {
                "success": False,
                "error": "Failed to extract muzzle embedding",
                "matches": []
            }

        # L2 normalize
        embedding = embedding / (np.linalg.norm(embedding) + 1e-8)
        embedding = embedding.reshape(1, -1).astype(np.float32)

        # Search FAISS index
        index, species_key = self._get_index(species)

        if index.ntotal == 0:
            return {
                "success": True,
                "matches": [],
                "message": f"No {species} muzzles registered yet",
                "index_size": 0
            }

        # Search top-K nearest
        k = min(top_k, index.ntotal)
        similarities, indices = index.search(embedding, k)

        # Build results
        matches = []
        seen_animals = set()

        for i in range(k):
            idx = int(indices[0][i])
            sim = float(similarities[0][i])

            if idx < 0 or idx >= len(self.metadata[species_key]):
                continue

            meta = self.metadata[species_key][idx]
            animal_id = meta["animal_id"]

            # Skip duplicates (same animal, different angles)
            if animal_id in seen_animals:
                continue
            seen_animals.add(animal_id)

            # Determine match quality
            if sim > 0.90:
                match_level = "HIGH_CONFIDENCE"
                color = "green"
            elif sim > 0.75:
                match_level = "MEDIUM_CONFIDENCE"
                color = "orange"
            elif sim > 0.60:
                match_level = "LOW_CONFIDENCE"
                color = "yellow"
            else:
                match_level = "NO_MATCH"
                color = "red"

            matches.append({
                "animal_id": animal_id,
                "similarity": round(sim * 100, 2),
                "match_level": match_level,
                "color": color,
                "species": meta.get("species", species),
                "registered_at": meta.get("registered_at", ""),
                "image_path": meta.get("image_path", "")
            })

        return {
            "success": True,
            "matches": matches,
            "query_species": species,
            "index_size": index.ntotal,
            "searched_at": datetime.now(IST).isoformat()
        }

    def verify_claim_muzzle(
        self,
        claim_image_path: str,
        registered_animal_id: str,
        species: str
    ) -> dict:
        """
        Verify a claim muzzle against the registered muzzle.
        Used for post-mortem verification.

        Returns similarity score with confidence level.
        """
        # Find registered embeddings for this animal
        _, species_key = self._get_index(species)

        registered_indices = [
            i for i, m in enumerate(self.metadata[species_key])
            if m["animal_id"] == registered_animal_id
        ]

        if not registered_indices:
            return {
                "success": False,
                "error": f"No registered muzzle found for animal {registered_animal_id}",
                "verified": False
            }

        # Extract claim muzzle embedding
        claim_embedding = self.engine.extract_embedding(claim_image_path, species)
        if claim_embedding is None:
            return {
                "success": False,
                "error": "Failed to extract claim muzzle embedding",
                "verified": False
            }

        # L2 normalize
        claim_embedding = claim_embedding / (np.linalg.norm(claim_embedding) + 1e-8)
        claim_embedding = claim_embedding.reshape(1, -1).astype(np.float32)

        # Compare against all registered embeddings for this animal
        index, _ = self._get_index(species)
        best_similarity = 0.0

        for reg_idx in registered_indices:
            # Reconstruct the registered embedding
            registered_vec = index.reconstruct(reg_idx)
            registered_vec = registered_vec.reshape(1, -1)

            # Cosine similarity (inner product on normalized vectors)
            sim = float(np.dot(claim_embedding, registered_vec.T)[0][0])
            best_similarity = max(best_similarity, sim)

        # Determine verification result
        if best_similarity > 0.80:
            verified = True
            confidence = "HIGH"
            message = "Muzzle verified — high confidence match"
        elif best_similarity > 0.60:
            verified = True
            confidence = "MEDIUM"
            message = "Muzzle partially matched — manual review recommended"
        else:
            verified = False
            confidence = "LOW"
            message = "Muzzle does NOT match — possible fraud alert"

        return {
            "success": True,
            "verified": verified,
            "similarity": round(best_similarity * 100, 2),
            "confidence": confidence,
            "message": message,
            "animal_id": registered_animal_id,
            "verified_at": datetime.now(IST).isoformat()
        }

    def _check_duplicate(self, embedding: np.ndarray, species_key: str) -> dict | None:
        """Check if a similar muzzle already exists (duplicate detection)."""
        index = self.cow_index if species_key == "cow" else self.mule_index

        if index.ntotal == 0:
            return None

        similarities, indices = index.search(embedding, 1)
        sim = float(similarities[0][0])
        idx = int(indices[0][0])

        if idx < 0 or idx >= len(self.metadata[species_key]):
            return None

        meta = self.metadata[species_key][idx]
        return {
            "animal_id": meta["animal_id"],
            "similarity": sim,
            "species": meta.get("species", "")
        }

    def get_stats(self) -> dict:
        """Get index statistics."""
        return {
            "cow_index_size": self.cow_index.ntotal if self.cow_index else 0,
            "mule_index_size": self.mule_index.ntotal if self.mule_index else 0,
            "total_registered": (
                (self.cow_index.ntotal if self.cow_index else 0) +
                (self.mule_index.ntotal if self.mule_index else 0)
            ),
            "embedding_dim": self.embedding_dim,
            "cow_animals": len(set(m["animal_id"] for m in self.metadata.get("cow", []))),
            "mule_animals": len(set(m["animal_id"] for m in self.metadata.get("mule", []))),
        }


# Singleton instance
_matcher: FAISSMuzzleMatcher | None = None


def get_matcher() -> FAISSMuzzleMatcher:
    """Get or create the singleton FAISS matcher."""
    global _matcher
    if _matcher is None:
        _matcher = FAISSMuzzleMatcher()
    return _matcher
