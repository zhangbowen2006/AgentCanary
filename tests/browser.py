"""Optional real-browser integration checks. Requires Python Playwright + Chromium."""
import sys
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 1440, "height": 1000})
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto(sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:4173", wait_until="networkidle")
    assert page.locator("#calls").inner_text() == "9"
    assert page.locator("#denied").inner_text() == "3"
    page.locator("#compare").click()
    assert "2" in page.locator("#comparison").inner_text()
    page.locator("#block-flow").uncheck()
    assert page.locator("#denied").inner_text() == "2"
    page.locator("#budget").fill("2000")
    page.locator("#budget").dispatch_event("change")
    assert page.locator("#denied").inner_text() == "1"
    page.locator("#need-approval").uncheck()
    assert page.locator("#denied").inner_text() == "0"
    page.reload(wait_until="networkidle")
    page.locator("#only-denied").check()
    assert page.locator(".event").count() == 3
    page.locator("#trace-editor").fill('[{"id":"<img src=x onerror=alert(1)>","session":"s","seq":0,"at_ms":0,"tool":"fs.read","resource":"/workspace/a"}]')
    page.locator("#replay").click()
    page.locator("#only-denied").uncheck()
    assert page.locator(".event-main strong").inner_text() == "<img src=x onerror=alert(1)>"
    assert page.locator("img").count() == 1
    page.locator("#trace-editor").fill("{invalid")
    page.locator("#replay").click()
    assert page.locator("#calls").inner_text() == "—"
    assert page.locator("#export-report").is_disabled()
    page.set_viewport_size({"width": 390, "height": 844})
    page.reload(wait_until="networkidle")
    assert page.evaluate("document.documentElement.scrollWidth") == 390
    assert not errors, errors
    browser.close()
    print("Browser integration checks passed; no uncaught page errors.")
