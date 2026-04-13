"""
XORA CattleShield 2.0 - Automated Demo Screenshot Capture
Captures all screens for client demo presentation.
"""

import os
import time
import json
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager

BASE_URL = "http://localhost:55357"
SCREENSHOT_DIR = "demo_screenshots"
WAIT_TIME = 3  # seconds to wait for page load

os.makedirs(SCREENSHOT_DIR, exist_ok=True)

def setup_driver():
    """Setup Chrome driver with mobile viewport."""
    options = Options()
    options.add_argument("--window-size=420,900")  # Mobile-like viewport
    options.add_argument("--force-device-scale-factor=1")
    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=options)
    return driver

def take_screenshot(driver, name, wait=WAIT_TIME):
    """Navigate and capture screenshot."""
    time.sleep(wait)
    filepath = os.path.join(SCREENSHOT_DIR, f"{name}.png")
    driver.save_screenshot(filepath)
    print(f"  [OK] {name}.png")
    return filepath

def clear_storage(driver):
    """Clear local storage and secure storage."""
    driver.execute_script("window.localStorage.clear(); window.sessionStorage.clear();")

def capture_farmer_flow(driver):
    """Capture all farmer screens."""
    print("\n=== FARMER FLOW ===")

    # 1. Splash
    driver.get(f"{BASE_URL}/#/splash")
    take_screenshot(driver, "01_splash", wait=2)

    # 2. Login page
    driver.get(f"{BASE_URL}/#/login")
    take_screenshot(driver, "02_login_farmer", wait=3)

    # 3. Enter phone number and send OTP
    try:
        phone_input = WebDriverWait(driver, 5).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "input[type='tel'], input"))
        )
        phone_input.clear()
        phone_input.send_keys("9876543210")
        take_screenshot(driver, "03_login_phone_entered", wait=1)

        # Click Send OTP button
        buttons = driver.find_elements(By.CSS_SELECTOR, "button, [role='button']")
        for btn in buttons:
            if "OTP" in btn.text or "Send" in btn.text:
                btn.click()
                break
        take_screenshot(driver, "04_otp_page", wait=3)
    except Exception as e:
        print(f"  [SKIP] Login interaction: {e}")

    # Navigate directly to farmer pages
    driver.get(f"{BASE_URL}/#/farmer")
    take_screenshot(driver, "05_farmer_dashboard", wait=4)

    driver.get(f"{BASE_URL}/#/farmer/animals")
    take_screenshot(driver, "06_farmer_animals", wait=3)

    driver.get(f"{BASE_URL}/#/farmer/policies")
    take_screenshot(driver, "07_farmer_policies", wait=3)

    driver.get(f"{BASE_URL}/#/farmer/proposals")
    take_screenshot(driver, "08_farmer_proposals", wait=3)

    driver.get(f"{BASE_URL}/#/farmer/claims")
    take_screenshot(driver, "09_farmer_claims", wait=3)

    driver.get(f"{BASE_URL}/#/farmer/profile")
    take_screenshot(driver, "10_farmer_profile", wait=3)

def capture_vet_flow(driver):
    """Capture all vet screens."""
    print("\n=== VET DOCTOR FLOW ===")

    # Clear and go to login
    clear_storage(driver)
    driver.get(f"{BASE_URL}/#/login")
    take_screenshot(driver, "11_login_vet_select", wait=3)

    # Navigate to vet pages directly
    driver.get(f"{BASE_URL}/#/vet")
    take_screenshot(driver, "12_vet_dashboard", wait=4)

    driver.get(f"{BASE_URL}/#/vet/reviews")
    take_screenshot(driver, "13_vet_reviews", wait=3)

    driver.get(f"{BASE_URL}/#/vet/certificates")
    take_screenshot(driver, "14_vet_certificates", wait=3)

    driver.get(f"{BASE_URL}/#/vet/profile")
    take_screenshot(driver, "15_vet_profile", wait=3)

def capture_admin_flow(driver):
    """Capture all admin screens."""
    print("\n=== UIIC ADMIN FLOW ===")

    clear_storage(driver)
    driver.get(f"{BASE_URL}/#/login")
    take_screenshot(driver, "16_login_admin_select", wait=3)

    driver.get(f"{BASE_URL}/#/admin")
    take_screenshot(driver, "17_admin_dashboard", wait=4)

    driver.get(f"{BASE_URL}/#/admin/pending-approvals")
    take_screenshot(driver, "18_admin_pending_approvals", wait=3)

    driver.get(f"{BASE_URL}/#/admin/audit-logs")
    take_screenshot(driver, "19_admin_audit_trail", wait=3)

    driver.get(f"{BASE_URL}/#/admin/fraud-alerts")
    take_screenshot(driver, "20_admin_fraud_alerts", wait=3)

    driver.get(f"{BASE_URL}/#/admin/profile")
    take_screenshot(driver, "21_admin_profile", wait=3)

def capture_scan_screens(driver):
    """Capture muzzle scan and health scan screens."""
    print("\n=== AI SCAN SCREENS ===")

    driver.get(f"{BASE_URL}/#/scan/muzzle-identify")
    take_screenshot(driver, "22_identify_animal", wait=3)

    driver.get(f"{BASE_URL}/#/farmer/animals/onboard")
    take_screenshot(driver, "23_register_animal_step1", wait=3)

def main():
    print("=" * 50)
    print("XORA CattleShield 2.0 - Demo Screenshot Capture")
    print("=" * 50)
    print(f"Base URL: {BASE_URL}")
    print(f"Output: {os.path.abspath(SCREENSHOT_DIR)}/")

    driver = setup_driver()

    try:
        capture_farmer_flow(driver)
        capture_vet_flow(driver)
        capture_admin_flow(driver)
        capture_scan_screens(driver)

        print("\n" + "=" * 50)
        print(f"DONE! {len(os.listdir(SCREENSHOT_DIR))} screenshots saved to:")
        print(f"  {os.path.abspath(SCREENSHOT_DIR)}/")
        print("=" * 50)

    finally:
        driver.quit()

if __name__ == "__main__":
    main()
