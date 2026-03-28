"""
XORA CattleShield 2.0 - Automated Demo Screenshots with Real Logins
Captures all screens for each role with actual authentication.
"""

import os
import time
import requests
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager

BASE_URL = "http://localhost:55357"
API_URL = "http://localhost:8000"
SCREENSHOT_DIR = "demo_screenshots"
WAIT = 3

os.makedirs(SCREENSHOT_DIR, exist_ok=True)


def setup_driver():
    options = Options()
    options.add_argument("--window-size=420,900")
    options.add_argument("--force-device-scale-factor=1")
    service = Service(ChromeDriverManager().install())
    return webdriver.Chrome(service=service, options=options)


def screenshot(driver, name, wait=WAIT):
    time.sleep(wait)
    path = os.path.join(SCREENSHOT_DIR, f"{name}.png")
    driver.save_screenshot(path)
    print(f"  [OK] {name}.png")


def login_farmer(driver, phone="7338995666", otp="123456"):
    """Login as farmer via OTP flow using API token injection."""
    print(f"\n  Logging in as Farmer ({phone})...")

    # Get token from API
    resp = requests.post(f"{API_URL}/api/auth/verify-otp", json={
        "phone": phone, "otp": otp
    })
    if resp.status_code != 200:
        print(f"  [ERROR] Farmer login failed: {resp.text}")
        return False

    data = resp.json()
    token = data["token"]
    user = data["user"]

    # Inject token into Flutter secure storage via localStorage
    driver.get(f"{BASE_URL}/#/login")
    time.sleep(2)

    # Store auth data in localStorage (Flutter web uses this)
    driver.execute_script(f"""
        window.localStorage.setItem('auth_token', '{token}');
        window.localStorage.setItem('user_data', JSON.stringify({str(user).replace("'", '"').replace('None', 'null').replace('True', 'true').replace('False', 'false')}));
    """)

    # Navigate to farmer dashboard
    driver.get(f"{BASE_URL}/#/farmer")
    time.sleep(3)
    print(f"  Logged in as: {user.get('name', phone)} (farmer)")
    return True


def login_credential(driver, agent_id, password, role):
    """Login as vet/admin/agent via credential flow."""
    print(f"\n  Logging in as {role} ({agent_id})...")

    resp = requests.post(f"{API_URL}/api/auth/login", json={
        "phone": agent_id, "password": password
    })
    if resp.status_code != 200:
        print(f"  [ERROR] {role} login failed: {resp.text}")
        return False

    data = resp.json()
    token = data["token"]
    user = data["user"]

    driver.get(f"{BASE_URL}/#/login")
    time.sleep(2)

    driver.execute_script(f"""
        window.localStorage.setItem('auth_token', '{token}');
        window.localStorage.setItem('user_data', JSON.stringify({str(user).replace("'", '"').replace('None', 'null').replace('True', 'true').replace('False', 'false')}));
    """)

    dashboard = "/vet" if role == "vet" else "/admin" if role == "admin" else "/farmer"
    driver.get(f"{BASE_URL}/#{dashboard}")
    time.sleep(3)
    print(f"  Logged in as: {user.get('name', agent_id)} ({role})")
    return True


def clear_session(driver):
    driver.get(f"{BASE_URL}/#/login")
    time.sleep(1)
    driver.execute_script("window.localStorage.clear(); window.sessionStorage.clear();")
    time.sleep(1)


def capture_splash_and_login(driver):
    print("\n" + "=" * 50)
    print("SPLASH & LOGIN SCREENS")
    print("=" * 50)

    clear_session(driver)

    # Splash
    driver.get(f"{BASE_URL}/#/splash")
    screenshot(driver, "01_splash_screen", wait=2)

    # Login - Farmer selected (default)
    driver.get(f"{BASE_URL}/#/login")
    screenshot(driver, "02_login_farmer_role", wait=3)


def capture_farmer_screens(driver):
    print("\n" + "=" * 50)
    print("FARMER FLOW (7338995666)")
    print("=" * 50)

    clear_session(driver)
    if not login_farmer(driver, "7338995666", "123456"):
        return

    # Dashboard
    driver.get(f"{BASE_URL}/#/farmer")
    screenshot(driver, "03_farmer_dashboard", wait=4)

    # Animals
    driver.get(f"{BASE_URL}/#/farmer/animals")
    screenshot(driver, "04_farmer_animals_list", wait=3)

    # Policies
    driver.get(f"{BASE_URL}/#/farmer/policies")
    screenshot(driver, "05_farmer_policies", wait=3)

    # Proposals
    driver.get(f"{BASE_URL}/#/farmer/proposals")
    screenshot(driver, "06_farmer_proposals", wait=3)

    # Claims
    driver.get(f"{BASE_URL}/#/farmer/claims")
    screenshot(driver, "07_farmer_claims", wait=3)

    # File Claim (policy selection)
    driver.get(f"{BASE_URL}/#/farmer/claims/new")
    screenshot(driver, "08_farmer_file_claim_select_policy", wait=3)

    # Register Animal
    driver.get(f"{BASE_URL}/#/farmer/animals/onboard")
    screenshot(driver, "09_farmer_register_animal", wait=3)

    # Identify Animal
    driver.get(f"{BASE_URL}/#/scan/muzzle-identify")
    screenshot(driver, "10_farmer_identify_animal", wait=3)

    # Profile
    driver.get(f"{BASE_URL}/#/farmer/profile")
    screenshot(driver, "11_farmer_profile", wait=3)


def capture_vet_screens(driver):
    print("\n" + "=" * 50)
    print("VET DOCTOR FLOW (vet001/vet123)")
    print("=" * 50)

    clear_session(driver)
    if not login_credential(driver, "vet001", "vet123", "vet"):
        return

    # Dashboard
    driver.get(f"{BASE_URL}/#/vet")
    screenshot(driver, "12_vet_dashboard", wait=4)

    # Reviews
    driver.get(f"{BASE_URL}/#/vet/reviews")
    screenshot(driver, "13_vet_reviews_list", wait=3)

    # Certificates
    driver.get(f"{BASE_URL}/#/vet/certificates")
    screenshot(driver, "14_vet_certificates", wait=3)

    # Profile
    driver.get(f"{BASE_URL}/#/vet/profile")
    screenshot(driver, "15_vet_profile", wait=3)


def capture_admin_screens(driver):
    print("\n" + "=" * 50)
    print("UIIC ADMIN FLOW (admin001/admin123)")
    print("=" * 50)

    clear_session(driver)
    if not login_credential(driver, "admin001", "admin123", "admin"):
        return

    # Dashboard
    driver.get(f"{BASE_URL}/#/admin")
    screenshot(driver, "16_admin_dashboard", wait=4)

    # Pending Approvals
    driver.get(f"{BASE_URL}/#/admin/pending-approvals")
    screenshot(driver, "17_admin_pending_approvals", wait=3)

    # Audit Logs
    driver.get(f"{BASE_URL}/#/admin/audit-logs")
    screenshot(driver, "18_admin_audit_trail", wait=3)

    # Fraud Alerts
    driver.get(f"{BASE_URL}/#/admin/fraud-alerts")
    screenshot(driver, "19_admin_fraud_alerts", wait=3)

    # Profile
    driver.get(f"{BASE_URL}/#/admin/profile")
    screenshot(driver, "20_admin_profile", wait=3)


def capture_agent_screens(driver):
    print("\n" + "=" * 50)
    print("AGENT FLOW (agent001/agent123)")
    print("=" * 50)

    clear_session(driver)
    if not login_credential(driver, "agent001", "agent123", "agent"):
        return

    # Agent uses farmer dashboard
    driver.get(f"{BASE_URL}/#/farmer")
    screenshot(driver, "21_agent_dashboard", wait=4)

    # Agent can register animals
    driver.get(f"{BASE_URL}/#/farmer/animals")
    screenshot(driver, "22_agent_animals", wait=3)

    # Agent profile
    driver.get(f"{BASE_URL}/#/farmer/profile")
    screenshot(driver, "23_agent_profile", wait=3)


def main():
    print("=" * 60)
    print("  XORA CattleShield 2.0 - Demo Screenshot Capture v2")
    print("  With Real Authentication for All 4 Roles")
    print("=" * 60)

    # Verify backend is running
    try:
        r = requests.get(f"{API_URL}/docs", timeout=3)
        print(f"\n  Backend: RUNNING ({API_URL})")
    except:
        print(f"\n  [ERROR] Backend not running at {API_URL}")
        print("  Start it: cd backend && python -m uvicorn main:app --reload --port 8000")
        return

    # Verify Flutter is running
    try:
        r = requests.get(BASE_URL, timeout=3)
        print(f"  Flutter:  RUNNING ({BASE_URL})")
    except:
        print(f"\n  [ERROR] Flutter not running at {BASE_URL}")
        print("  Start it: flutter run -d chrome --web-port 55357")
        return

    driver = setup_driver()

    try:
        capture_splash_and_login(driver)
        capture_farmer_screens(driver)
        capture_vet_screens(driver)
        capture_admin_screens(driver)
        capture_agent_screens(driver)

        total = len([f for f in os.listdir(SCREENSHOT_DIR) if f.endswith('.png')])
        print("\n" + "=" * 60)
        print(f"  DONE! {total} screenshots saved to:")
        print(f"  {os.path.abspath(SCREENSHOT_DIR)}")
        print("=" * 60)
        print("\n  Screenshots by role:")
        print("  01-02: Splash & Login")
        print("  03-11: Farmer (7338995666)")
        print("  12-15: Vet Doctor (vet001)")
        print("  16-20: UIIC Admin (admin001)")
        print("  21-23: Agent (agent001)")

    finally:
        driver.quit()


if __name__ == "__main__":
    main()
