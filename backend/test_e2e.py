"""End-to-end test for CattleShield 2.0 API."""
import io
import sys
import requests
from PIL import Image

BASE = "http://localhost:8000/api"
PASS = 0
FAIL = 0

def test(name, condition, detail=""):
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"  PASS: {name}")
    else:
        FAIL += 1
        print(f"  FAIL: {name} - {detail}")

def create_test_image(color="brown", size=(400, 300)):
    """Create a test image to simulate muzzle/health photos."""
    img = Image.new("RGB", size, color)
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)
    return buf

print("=" * 60)
print("CattleShield 2.0 - End-to-End API Test")
print("=" * 60)

# ─── 1. OTP Login ───
print("\n--- 1. Farmer OTP Login ---")
r = requests.post(f"{BASE}/auth/verify-otp", json={"phone": "7338995666", "otp": "123456"})
test("OTP verify returns 200", r.status_code == 200, f"status={r.status_code}")
data = r.json()
TOKEN = data.get("token", "")
test("Token returned", len(TOKEN) > 10)
test("User role is farmer", data.get("user", {}).get("role") == "farmer")
FARMER_HEADERS = {"Authorization": f"Bearer {TOKEN}"}

# ─── 2. Vet Login ───
print("\n--- 2. Vet Login ---")
r = requests.post(f"{BASE}/auth/login", json={"phone": "vet001", "password": "vet123"})
test("Vet login returns 200", r.status_code == 200, f"status={r.status_code}")
VET_TOKEN = r.json().get("token", "")
test("Vet token returned", len(VET_TOKEN) > 10)
VET_HEADERS = {"Authorization": f"Bearer {VET_TOKEN}"}

# ─── 3. Admin Login ───
print("\n--- 3. Admin Login ---")
r = requests.post(f"{BASE}/auth/login", json={"phone": "admin001", "password": "admin123"})
test("Admin login returns 200", r.status_code == 200, f"status={r.status_code}")
ADMIN_TOKEN = r.json().get("token", "")
test("Admin token returned", len(ADMIN_TOKEN) > 10)

# ─── 4. Register Cow ───
print("\n--- 4. Register Cow ---")
r = requests.post(f"{BASE}/animals/", headers=FARMER_HEADERS, json={
    "species": "cow", "breed": "Gir", "sex": "female", "color": "Brown and White",
    "age_years": 4, "identification_tag": "TAG-COW-001",
    "market_value": 50000, "sum_insured": 40000,
    "distinguishing_marks": "White patch on forehead"
})
test("Cow registration returns 200/201", r.status_code in (200, 201), f"status={r.status_code}")
cow = r.json()
COW_ID = cow.get("id", "")
test("Cow ID assigned", len(COW_ID) > 0)
test("Unique ID assigned", "unique_id" in cow)
print(f"    Cow ID: {COW_ID}")
print(f"    Unique ID: {cow.get('unique_id')}")

# ─── 5. Register Mule ───
print("\n--- 5. Register Mule ---")
r = requests.post(f"{BASE}/animals/", headers=FARMER_HEADERS, json={
    "species": "mule", "breed": "Local", "sex": "male", "color": "Dark Brown",
    "age_years": 6, "identification_tag": "TAG-MULE-001",
    "market_value": 30000, "sum_insured": 25000,
})
test("Mule registration returns 200/201", r.status_code in (200, 201), f"status={r.status_code}")
mule = r.json()
MULE_ID = mule.get("id", "")
test("Mule ID assigned", len(MULE_ID) > 0)
print(f"    Mule ID: {MULE_ID}")

# ─── 6. Muzzle Registration (Cow - single) ───
print("\n--- 6. Muzzle Registration (Cow - CNN) ---")
cow_img = create_test_image("saddlebrown")
r = requests.post(
    f"{BASE}/ai/muzzle-register/{COW_ID}",
    headers=FARMER_HEADERS,
    files={"file": ("cow_muzzle.jpg", cow_img, "image/jpeg")},
)
test("Cow muzzle register returns 200", r.status_code == 200, f"status={r.status_code} body={r.text[:200]}")
if r.status_code == 200:
    muzzle_data = r.json()
    test("Muzzle ID assigned", "muzzle_id" in muzzle_data)
    test("Image saved with SHA-256", "image" in muzzle_data and "sha256_hash" in muzzle_data.get("image", {}))
    print(f"    Muzzle ID: {muzzle_data.get('muzzle_id')}")
    print(f"    Model: {muzzle_data.get('model')}")
    print(f"    Image path: {muzzle_data.get('image', {}).get('path')}")

# ─── 7. Muzzle Registration (Mule - single) ───
print("\n--- 7. Muzzle Registration (Mule - CNN) ---")
mule_img = create_test_image("sienna")
r = requests.post(
    f"{BASE}/ai/muzzle-register/{MULE_ID}",
    headers=FARMER_HEADERS,
    files={"file": ("mule_muzzle.jpg", mule_img, "image/jpeg")},
)
test("Mule muzzle register returns 200", r.status_code == 200, f"status={r.status_code} body={r.text[:200]}")
if r.status_code == 200:
    muzzle_data = r.json()
    test("Mule muzzle ID prefix", muzzle_data.get("muzzle_id", "").startswith("EQMZ") or muzzle_data.get("muzzle_id", "").startswith("MZL"))
    print(f"    Muzzle ID: {muzzle_data.get('muzzle_id')}")
    print(f"    Pipeline: {muzzle_data.get('pipeline', muzzle_data.get('model'))}")

# ─── 8. Muzzle Multi-Angle Registration (Cow) ───
print("\n--- 8. Muzzle Multi-Angle Registration (3 angles) ---")
r = requests.post(
    f"{BASE}/ai/muzzle-register-multi/{COW_ID}",
    headers=FARMER_HEADERS,
    files={
        "front": ("front.jpg", create_test_image("chocolate"), "image/jpeg"),
        "left": ("left.jpg", create_test_image("peru"), "image/jpeg"),
        "right": ("right.jpg", create_test_image("sandybrown"), "image/jpeg"),
    },
)
test("Multi-angle register returns 200", r.status_code == 200, f"status={r.status_code} body={r.text[:200]}")
if r.status_code == 200:
    multi = r.json()
    test("3 angles captured", multi.get("angles_captured") == 3)
    test("Images stored", len(multi.get("images", [])) == 3)
    for img in multi.get("images", []):
        print(f"    {img.get('angle')}: {img.get('path')} (SHA: {img.get('sha256_hash', '')[:16]}...)")

# ─── 9. Muzzle Identify (Search DB by scan) ───
print("\n--- 9. Muzzle Identify (Cow) ---")
search_img = create_test_image("saddlebrown")
r = requests.post(
    f"{BASE}/ai/muzzle-identify?species=cow",
    headers=FARMER_HEADERS,
    files={"file": ("scan.jpg", search_img, "image/jpeg")},
)
test("Identify returns 200", r.status_code == 200, f"status={r.status_code} body={r.text[:200]}")
if r.status_code == 200:
    ident = r.json()
    test("Match found", ident.get("matched") == True)
    test("Confidence > 0", (ident.get("confidence") or 0) > 0)
    test("Animal details returned", ident.get("animal") is not None)
    print(f"    Matched: {ident.get('matched')}")
    print(f"    Confidence: {ident.get('confidence')}%")
    print(f"    Model: {ident.get('model_version')}")
    print(f"    Animal: {ident.get('animal', {}).get('unique_id')}")

# ─── 10. Muzzle Identify (Mule) ───
print("\n--- 10. Muzzle Identify (Mule) ---")
r = requests.post(
    f"{BASE}/ai/muzzle-identify?species=mule",
    headers=FARMER_HEADERS,
    files={"file": ("scan.jpg", create_test_image("sienna"), "image/jpeg")},
)
test("Mule identify returns 200", r.status_code == 200, f"status={r.status_code}")
if r.status_code == 200:
    ident = r.json()
    test("Species searched is mule", ident.get("species_searched") == "mule")
    print(f"    Matched: {ident.get('matched')}, Confidence: {ident.get('confidence')}%")

# ─── 11. Health Score ───
print("\n--- 11. AI Health Score ---")
r = requests.get(f"{BASE}/ai/health-score/{COW_ID}", headers=FARMER_HEADERS)
test("Health score returns 200", r.status_code == 200, f"status={r.status_code}")
if r.status_code == 200:
    health = r.json()
    test("Score between 0-100", 0 <= health.get("score", -1) <= 100)
    print(f"    Score: {health.get('score')}/100 ({health.get('risk_label')})")

# ─── 12. Create Proposal ───
print("\n--- 12. Create Proposal ---")
r = requests.post(f"{BASE}/proposals/", headers=FARMER_HEADERS, json={
    "animal_id": COW_ID,
    "sum_insured": 40000,
    "form_data": {"purpose": "dairy", "shed_type": "pucca"}
})
test("Proposal creation returns 200/201", r.status_code in (200, 201), f"status={r.status_code} body={r.text[:200]}")
PROPOSAL_ID = r.json().get("id", "") if r.status_code in (200, 201) else ""

# ─── 13. Vet Pending Queue ───
print("\n--- 13. Vet Pending Queue ---")
r = requests.get(f"{BASE}/vet/pending", headers=VET_HEADERS)
test("Vet pending returns 200", r.status_code == 200, f"status={r.status_code}")

# ─── 14. List Animals ───
print("\n--- 14. List Animals ---")
r = requests.get(f"{BASE}/animals/", headers=FARMER_HEADERS)
test("List animals returns 200", r.status_code == 200)
animals = r.json()
test("At least 2 animals registered", len(animals) >= 2, f"count={len(animals)}")
print(f"    Total animals: {len(animals)}")

# ─── 15. Verify File Storage ───
print("\n--- 15. Verify File Storage ---")
import os
upload_dir = os.path.join(os.path.dirname(__file__), "uploads", "muzzle_scans")
if os.path.exists(upload_dir):
    for species_dir in os.listdir(upload_dir):
        species_path = os.path.join(upload_dir, species_dir)
        if os.path.isdir(species_path):
            for animal_dir in os.listdir(species_path):
                animal_path = os.path.join(species_path, animal_dir)
                if os.path.isdir(animal_path):
                    files = os.listdir(animal_path)
                    print(f"    {species_dir}/{animal_dir[:8]}...: {len(files)} files")
                    for f in files:
                        print(f"      - {f}")
    test("Muzzle scan folders created", True)
else:
    test("Muzzle scan folders created", False, "uploads/muzzle_scans not found")

# ─── Summary ───
print("\n" + "=" * 60)
print(f"RESULTS: {PASS} passed, {FAIL} failed, {PASS + FAIL} total")
print("=" * 60)
sys.exit(0 if FAIL == 0 else 1)
