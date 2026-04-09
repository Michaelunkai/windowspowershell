import sys
sys.stdout.reconfigure(encoding='utf-8')
from playwright.sync_api import sync_playwright
import time

with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp('http://127.0.0.1:9222')
    ctx = browser.contexts[0]
    page = ctx.new_page()
    page.goto('https://www.linkedin.com/jobs/search/?keywords=devops%20engineer%20israel&f_E=2', timeout=30000, wait_until='domcontentloaded')
    time.sleep(6)
    
    print(f'URL: {page.url}')
    logged_in = page.query_selector('.global-nav__me')
    print(f'Logged in: {bool(logged_in)}')
    print(f'Title: {page.title()}')
    
    selectors = [
        '.scaffold-layout__list-item',
        '.job-card-container',
        '[data-job-id]',
        '.jobs-search-results__list-item',
        'li.ember-view',
        'ul.scaffold-layout__list-container > li',
        '.jobs-search-two-pane__wrapper',
        '.job-card-container--clickable',
        'div[data-view-name="job-card"]',
        '.jobs-search-results-list li',
        'a[href*="/jobs/view/"]',
    ]
    for sel in selectors:
        els = page.query_selector_all(sel)
        print(f'{sel}: {len(els)} elements')
    
    # Get main content area HTML
    html = page.evaluate('''() => {
        const main = document.querySelector('.scaffold-layout__list-container') 
            || document.querySelector('.jobs-search-results-list')
            || document.querySelector('main');
        return main ? main.innerHTML.substring(0, 3000) : 'NOT FOUND';
    }''')
    print(f'\nHTML:\n{html[:2000]}')
    
    page.close()
