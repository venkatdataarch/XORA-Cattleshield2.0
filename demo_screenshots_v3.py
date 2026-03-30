"""
XORA CattleShield 2.0 - Demo Screenshots v3
Uses actual UI clicks to login, then captures screenshots.
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
from selenium.webdriver.common.action_chains import ActionChains
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


def wait_for_flutter(driver, timeout=10):
    """Wait for Flutter to finish loading."""
    time.sleep(2)
    for _ in range(timeout):
        try:
            # Check if loading spinner is gone
            spinners = driver.find_elements(By.CSS_SELECTOR, "flt-semantics-placeholder")
            if spinners:
                time.sleep(1)
                continue
            break
        except:
            time.sleep(1)


def find_and_click(driver, text, timeout=5):
    """Find element by text content and click it."""
    time.sleep(1)
    try:
        # Try multiple selectors for Flutter web
        elements = driver.find_elements(By.XPATH, f"//*[contains(text(), '{text}')]")
        for el in elements:
            if el.is_displayed():
                el.click()
                return True
        # Try flt-semantics
        elements = driver.find_elements(By.CSS_SELECTOR, f"[aria-label*='{text}']")
        for el in elements:
            if el.is_displayed():
                el.click()
                return True
    except Exception as e:
        print(f"  [WARN] Could not click '{text}': {e}")
    return False


def find_input_and_type(driver, value, index=0):
    """Find input field and type value."""
    time.sleep(1)
    try:
        inputs = driver.find_elements(By.CSS_SELECTOR, "input")
        if len(inputs) > index:
            inputs[index].clear()
            inputs[index].send_keys(value)
            return True
        # Try flt-semantics input
        inputs = driver.find_elements(By.CSS_SELECTOR, "[role='textbox'], [contenteditable='true']")
        if len(inputs) > index:
            inputs[index].click()
            ActionChains(driver).send_keys(value).perform()
            return True
    except Exception as e:
        print(f"  [WARN] Could not type: {e}")
    return False


def login_as_farmer(driver, phone="7338995666"):
    """Login as farmer using OTP flow via UI."""
    print(f"\n  Logging in as Farmer ({phone})...")

    driver.get(f"{BASE_URL}/#/login")
    time.sleep(4)

    # Click "Farmer" role card (should be selected by default)
    find_and_click(driver, "Farmer")
    time.sleep(1)

    # Find phone input and enter number
    find_input_and_type(driver, phone, index=0)
    time.sleep(1)
    screenshot(driver, "02a_login_phone_entered", wait=1)

    # Click Send OTP
    find_and_click(driver, "Send OTP")
    time.sleep(3)

    # Enter OTP digits - find all inputs on OTP page
    screenshot(driver, "02b_otp_page", wait=2)

    # Type OTP digits
    inputs = driver.find_elements(By.CSS_SELECTOR, "input")
    if len(inputs) >= 6:
        for i in range(6):
            inputs[i].send_keys(str(i + 1))
    elif len(inputs) >= 1:
        inputs[0].send_keys("123456")
    time.sleep(1)

    # Click Verify
    find_and_click(driver, "Verify")
    time.sleep(4)

    # Check if we're on dashboard
    if "/farmer" in driver.current_url:
        print("  Logged in as Farmer!")
        return True

    # Try navigating directly
    driver.get(f"{BASE_URL}/#/farmer")
    time.sleep(3)
    return "/farmer" in driver.current_url


def login_as_credential(driver, role_label, agent_id, password, role):
    """Login as vet/admin/agent using credential flow via UI."""
    print(f"\n  Logging in as {role} ({agent_id})...")

    driver.get(f"{BASE_URL}/#/login")
    time.sleep(4)

    # Click the role card
    find_and_click(driver, role_label)
    time.sleep(2)

    # Find inputs - first is Agent/Doctor/Admin ID, second is Password
    inputs = driver.find_elements(By.CSS_SELECTOR, "input")
    if len(inputs) >= 2:
        inputs[0].clear()
        inputs[0].send_keys(agent_id)
        time.sleep(0.5)
        inputs[1].clear()
        inputs[1].send_keys(password)
        time.sleep(0.5)
    elif len(inputs) >= 1:
        inputs[0].send_keys(agent_id)
        time.sleep(0.5)
        # Find password field
        inputs = driver.find_elements(By.CSS_SELECTOR, "input")
        if len(inputs) >= 2:
            inputs[1].send_keys(password)

    screenshot(driver, f"{role}_login_filled", wait=1)

    # Click Login button
    find_and_click(driver, "Login")
    time.sleep(5)

    dashboard = "/vet" if role == "vet" else "/admin" if role == "admin" else "/farmer"
    if dashboard in driver.current_url:
        print(f"  Logged in as {role}!")
        return True

    # Try direct navigation
    driver.get(f"{BASE_URL}/#{dashboard}")
    time.sleep(3)
    return True


def capture_splash(driver):
    print("\n" + "=" * 50)
    print("SPLASH SCREEN")
    print("=" * 50)

    # Clear everything
    driver.get(f"{BASE_URL}/#/splash")
    time.sleep(1)
    screenshot(driver, "01_splash_screen", wait=2)


def capture_farmer(driver):
    print("\n" + "=" * 50)
    print("FARMER FLOW")
    print("=" * 50)

    login_as_farmer(driver, "7338995666")

    pages = [
        ("farmer", "03_farmer_dashboard", 4),
        ("farmer/animals", "04_farmer_animals_list", 3),
        ("farmer/policies", "05_farmer_policies", 3),
        ("farmer/proposals", "06_farmer_proposals", 3),
        ("farmer/claims", "07_farmer_claims", 3),
        ("farmer/claims/new", "08_farmer_file_claim", 3),
        ("farmer/animals/onboard", "09_farmer_register_animal", 3),
        ("scan/muzzle-identify", "10_farmer_identify_animal", 3),
        ("farmer/profile", "11_farmer_profile", 3),
    ]

    for path, name, wait in pages:
        driver.get(f"{BASE_URL}/#{path}")
        screenshot(driver, name, wait=wait)


def capture_vet(driver):
    print("\n" + "=" * 50)
    print("VET DOCTOR FLOW")
    print("=" * 50)

    # Clear storage and re-login
    driver.execute_script("window.localStorage.clear();")
    login_as_credential(driver, "Vet Doctor", "vet001", "vet123", "vet")

    pages = [
        ("vet", "12_vet_dashboard", 4),
        ("vet/reviews", "13_vet_reviews_list", 3),
        ("vet/certificates", "14_vet_certificates", 3),
        ("vet/profile", "15_vet_profile", 3),
    ]

    for path, name, wait in pages:
        driver.get(f"{BASE_URL}/#{path}")
        screenshot(driver, name, wait=wait)


def capture_admin(driver):
    print("\n" + "=" * 50)
    print("UIIC ADMIN FLOW")
    print("=" * 50)

    driver.execute_script("window.localStorage.clear();")
    login_as_credential(driver, "UIIC Admin", "admin001", "admin123", "admin")

    pages = [
        ("admin", "16_admin_dashboard", 4),
        ("admin/pending-approvals", "17_admin_pending_approvals", 3),
        ("admin/audit-logs", "18_admin_audit_trail", 3),
        ("admin/fraud-alerts", "19_admin_fraud_alerts", 3),
        ("admin/profile", "20_admin_profile", 3),
    ]

    for path, name, wait in pages:
        driver.get(f"{BASE_URL}/#{path}")
        screenshot(driver, name, wait=wait)


def capture_agent(driver):
    print("\n" + "=" * 50)
    print("AGENT FLOW")
    print("=" * 50)

    driver.execute_script("window.localStorage.clear();")
    login_as_credential(driver, "Agent", "agent001", "agent123", "agent")

    pages = [
        ("farmer", "21_agent_dashboard", 4),
        ("farmer/animals", "22_agent_animals", 3),
        ("farmer/profile", "23_agent_profile", 3),
    ]

    for path, name, wait in pages:
        driver.get(f"{BASE_URL}/#{path}")
        screenshot(driver, name, wait=wait)


def main():
    print("=" * 60)
    print("  XORA CattleShield 2.0 - Demo Screenshots v3")
    print("  Real UI Login for All 4 Roles")
    print("=" * 60)

    driver = setup_driver()

    try:
        capture_splash(driver)
        capture_farmer(driver)
        capture_vet(driver)
        capture_admin(driver)
        capture_agent(driver)

        total = len([f for f in os.listdir(SCREENSHOT_DIR) if f.endswith('.png')])
        print("\n" + "=" * 60)
        print(f"  DONE! {total} screenshots saved to:")
        print(f"  {os.path.abspath(SCREENSHOT_DIR)}")
        print("=" * 60)
    finally:
        driver.quit()


if __name__ == "__main__":
    main()
