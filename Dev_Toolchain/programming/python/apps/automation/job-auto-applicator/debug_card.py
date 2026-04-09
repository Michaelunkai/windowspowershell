import sys
sys.stdout.reconfigure(encoding='utf-8')
from playwright.sync_api import sync_playwright
import time

with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp('http://127.0.0.1:9222')
    ctx = browser.contexts[0]
    page = ctx.new_page()
    page.goto('https://www.linkedin.com/jobs/search?keywords=DevOps+Engineer&location=Israel', timeout=30000, wait_until='domcontentloaded')
    time.sleep(5)
    
    cards = page.query_selector_all('.base-search-card')
    print(f"Found {len(cards)} cards\n")
    
    for i, card in enumerate(cards[:8]):
        title_el = card.query_selector('.base-search-card__title')
        company_el = card.query_selector('.base-search-card__subtitle a')
        location_el = card.query_selector('.job-search-card__location')
        link_el = card.query_selector('a.base-card__full-link')
        
        title = title_el.inner_text().strip() if title_el else "N/A"
        company = company_el.inner_text().strip() if company_el else "N/A"
        location = location_el.inner_text().strip() if location_el else "N/A"
        href = link_el.get_attribute('href') if link_el else "N/A"
        
        print(f"[{i}] {title}")
        print(f"    Company: {company}")
        print(f"    Location: {location}")
        print(f"    URL: {href[:80]}")
        print()
    
    # Click on first non-senior card and get job description
    for card in cards[:10]:
        title_el = card.query_selector('.base-search-card__title')
        title = title_el.inner_text().strip() if title_el else ""
        if "senior" not in title.lower() and "lead" not in title.lower():
            link = card.query_selector('a.base-card__full-link')
            if link:
                href = link.get_attribute('href')
                print(f"\nClicking: {title}")
                page.goto(href, timeout=30000, wait_until='domcontentloaded')
                time.sleep(3)
                
                # Get job description
                desc_el = page.query_selector('.show-more-less-html__markup, .description__text, .decorated-job-posting__details')
                if desc_el:
                    desc = desc_el.inner_text()[:500]
                    print(f"Description:\n{desc}")
                
                # Check for Easy Apply button
                apply_btn = page.query_selector('.apply-button, a[data-tracking-control-name*="apply"], a.apply-button--top-card')
                if apply_btn:
                    print(f"\nApply button found: {apply_btn.inner_text().strip()}")
                    apply_href = apply_btn.get_attribute('href')
                    print(f"Apply URL: {apply_href[:100] if apply_href else 'N/A'}")
                break
    
    page.close()
