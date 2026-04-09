import sys
sys.stdout.reconfigure(encoding='utf-8')
from playwright.sync_api import sync_playwright
import time

with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp('http://127.0.0.1:9222')
    ctx = browser.contexts[0]
    
    # Use an existing tab instead of creating new one
    pages = ctx.pages
    print(f"Existing tabs: {len(pages)}")
    for i, pg in enumerate(pages):
        print(f"  Tab {i}: {pg.url[:80]}")
    
    # Check if any tab is already on LinkedIn
    linkedin_page = None
    for pg in pages:
        if "linkedin.com" in pg.url:
            linkedin_page = pg
            break
    
    if linkedin_page:
        print(f"\nFound LinkedIn tab: {linkedin_page.url}")
        logged_in = linkedin_page.query_selector('.global-nav__me')
        print(f"Logged in: {bool(logged_in)}")
    else:
        print("\nNo LinkedIn tab found")
    
    # Try public LinkedIn job search (no login needed)
    page = ctx.new_page()
    page.goto('https://www.linkedin.com/jobs/search?keywords=DevOps+Engineer&location=Israel&trk=public_jobs_jobs-search-bar_search-submit', timeout=30000, wait_until='domcontentloaded')
    time.sleep(5)
    
    print(f'\nPublic search URL: {page.url}')
    print(f'Title: {page.title()}')
    
    # Try public job page selectors
    public_selectors = [
        '.jobs-search__results-list li',
        '.base-card',
        '.base-search-card',
        '.job-search-card',
        'ul.jobs-search__results-list > li',
        'a[data-tracking-control-name="public_jobs_jserp-result_search-card"]',
    ]
    for sel in public_selectors:
        els = page.query_selector_all(sel)
        print(f'{sel}: {len(els)} elements')
    
    # Get links
    links = page.query_selector_all('a[href*="/jobs/view/"]')
    print(f'\nJob links: {len(links)}')
    for link in links[:5]:
        href = link.get_attribute('href')
        text = link.inner_text().strip()[:80]
        print(f'  {text} -> {href[:60]}')
    
    page.close()
