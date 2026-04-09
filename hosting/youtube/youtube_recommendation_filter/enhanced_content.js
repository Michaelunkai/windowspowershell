// Enhanced Content Script - YouTube Recommendation Filter v1.1
// More aggressive filtering with ML-like scoring and real-time API interception

console.log('YouTube Recommendation Filter v1.1 - Enhanced Mode');

let settings = {
  hideWatched: true,
  watchThreshold: 50,
  boostSubscriptions: true,
  enableSync: true,
  hideShorts: false,
  hideLivestreams: false,
  minDuration: 0,
  maxDuration: 0,
  keywordBlacklist: [],
  channelQualityScore: true,
  diversityMode: false
};

let watchedVideos = new Set();
let blockedChannels = new Set();
let boostedChannels = new Set();
let videoScores = new Map();
let processedVideos = new Set();
let hiddenCount = 0;
let observer = null;

// Enhanced initialization
(async function init() {
  await loadSettings();
  await loadData();
  startObserver();
  interceptNetworkRequests();
  addKeyboardShortcuts();
  createFloatingUI();
  
  // Monitor URL changes for SPA navigation
  let lastUrl = location.href;
  new MutationObserver(() => {
    const url = location.href;
    if (url !== lastUrl) {
      lastUrl = url;
      setTimeout(() => {
        filterVideos();
        updateFloatingUI();
      }, 500);
    }
  }).observe(document, { subtree: true, childList: true });
  
  // Initial filter
  setTimeout(filterVideos, 1000);
})();

// Load all data from background
async function loadData() {
  try {
    const response = await chrome.runtime.sendMessage({ action: 'getSettings' });
    if (response) {
      settings = { ...settings, ...response.settings };
      
      // Load watched videos
      const watchedData = await chrome.storage.local.get('watchedVideos');
      if (watchedData.watchedVideos) {
        watchedVideos = new Set(watchedData.watchedVideos);
      }
      
      // Load blocked channels
      const blockedData = await chrome.storage.local.get('blockedChannels');
      if (blockedData.blockedChannels) {
        blockedChannels = new Set(blockedData.blockedChannels);
      }
      
      // Load boosted channels
      const boostedData = await chrome.storage.local.get('boostedChannels');
      if (boostedData.boostedChannels) {
        boostedChannels = new Set(boostedData.boostedChannels);
      }
      
      console.log(`Loaded: ${watchedVideos.size} watched, ${blockedChannels.size} blocked, ${boostedChannels.size} boosted`);
    }
  } catch (error) {
    console.error('Error loading data:', error);
  }
}

async function loadSettings() {
  try {
    const response = await chrome.runtime.sendMessage({ action: 'getSettings' });
    if (response && response.settings) {
      settings = { ...settings, ...response.settings };
    }
  } catch (error) {
    console.error('Error loading settings:', error);
  }
}

// Enhanced observer with performance optimization
function startObserver() {
  if (observer) observer.disconnect();
  
  observer = new MutationObserver((mutations) => {
    // Debounce rapid changes
    clearTimeout(observer.timeout);
    observer.timeout = setTimeout(filterVideos, 300);
  });
  
  observer.observe(document.body, {
    childList: true,
    subtree: true
  });
}

// UPGRADED: More comprehensive filtering with scoring system
async function filterVideos() {
  if (!settings.hideWatched) return;
  
  const selectors = [
    'ytd-video-renderer',
    'ytd-grid-video-renderer',
    'ytd-compact-video-renderer',
    'ytd-rich-item-renderer',
    'ytd-playlist-video-renderer',
    'ytd-movie-renderer',
    'ytd-reel-item-renderer' // Shorts
  ];
  
  let currentHidden = 0;
  
  for (const selector of selectors) {
    const videos = document.querySelectorAll(selector);
    
    for (const video of videos) {
      try {
        const videoId = extractVideoId(video);
        if (!videoId) continue;
        
        // Skip if already processed
        if (processedVideos.has(videoId)) continue;
        processedVideos.add(videoId);
        
        // Calculate video score
        const score = await calculateVideoScore(video, videoId);
        videoScores.set(videoId, score);
        
        // Decision: hide or show
        if (score.shouldHide) {
          hideVideo(video, score.reason);
          currentHidden++;
        } else if (score.shouldBoost) {
          boostVideo(video, score.boostReason);
        }
        
      } catch (error) {
        // Silent fail for individual videos
      }
    }
  }
  
  hiddenCount = currentHidden;
  updateFloatingUI();
  
  // Clean cache periodically
  if (processedVideos.size > 2000) {
    processedVideos.clear();
  }
}

// UPGRADED: ML-like scoring system
async function calculateVideoScore(element, videoId) {
  let score = {
    shouldHide: false,
    shouldBoost: false,
    reason: '',
    boostReason: '',
    points: 0
  };
  
  // Check if watched (highest priority)
  if (watchedVideos.has(videoId)) {
    score.shouldHide = true;
    score.reason = 'Already watched';
    score.points -= 100;
    return score;
  }
  
  // Extract video metadata
  const metadata = extractVideoMetadata(element);
  
  // Check blocked channels
  if (metadata.channelId && blockedChannels.has(metadata.channelId)) {
    score.shouldHide = true;
    score.reason = 'Blocked channel';
    score.points -= 50;
    return score;
  }
  
  // Check Shorts filter
  if (settings.hideShorts && metadata.isShort) {
    score.shouldHide = true;
    score.reason = 'Shorts filtered';
    score.points -= 30;
    return score;
  }
  
  // Check Livestream filter
  if (settings.hideLivestreams && metadata.isLive) {
    score.shouldHide = true;
    score.reason = 'Livestream filtered';
    score.points -= 30;
    return score;
  }
  
  // Duration filters
  if (settings.minDuration && metadata.duration && metadata.duration < settings.minDuration) {
    score.shouldHide = true;
    score.reason = `Too short (<${Math.floor(settings.minDuration/60)}m)`;
    score.points -= 20;
    return score;
  }
  
  if (settings.maxDuration && metadata.duration && metadata.duration > settings.maxDuration) {
    score.shouldHide = true;
    score.reason = `Too long (>${Math.floor(settings.maxDuration/60)}m)`;
    score.points -= 20;
    return score;
  }
  
  // Keyword blacklist
  if (settings.keywordBlacklist && settings.keywordBlacklist.length > 0) {
    const titleLower = metadata.title.toLowerCase();
    for (const keyword of settings.keywordBlacklist) {
      if (titleLower.includes(keyword.toLowerCase())) {
        score.shouldHide = true;
        score.reason = `Blacklisted keyword: "${keyword}"`;
        score.points -= 25;
        return score;
      }
    }
  }
  
  // BOOSTING LOGIC
  
  // Boosted channels
  if (metadata.channelId && boostedChannels.has(metadata.channelId)) {
    score.shouldBoost = true;
    score.boostReason = 'Boosted channel';
    score.points += 50;
  }
  
  // Quality scoring (engagement-based)
  if (settings.channelQualityScore && metadata.views && metadata.uploadDate) {
    const daysSince = (Date.now() - metadata.uploadDate) / (1000 * 60 * 60 * 24);
    const engagement = metadata.views / Math.max(daysSince, 1);
    
    if (engagement > 10000) {
      score.points += 20;
      if (!score.shouldBoost) {
        score.shouldBoost = true;
        score.boostReason = 'High engagement';
      }
    }
  }
  
  // Diversity mode (hide if similar to recently watched)
  if (settings.diversityMode && metadata.channelId) {
    // Check if we've watched a lot from this channel recently
    // (simplified - would need watch history analysis)
    const recentWatched = Array.from(watchedVideos).slice(-50);
    // This is a placeholder - full implementation would check channel IDs
  }
  
  return score;
}

// UPGRADED: Extract comprehensive metadata
function extractVideoMetadata(element) {
  const metadata = {
    title: '',
    channelId: '',
    channelName: '',
    duration: 0,
    views: 0,
    uploadDate: null,
    isShort: false,
    isLive: false
  };
  
  // Title
  const titleEl = element.querySelector('#video-title, h3, a#video-title-link');
  if (titleEl) {
    metadata.title = titleEl.textContent.trim();
  }
  
  // Check if Shorts
  const link = element.querySelector('a#video-title, a#thumbnail');
  if (link && link.href) {
    metadata.isShort = link.href.includes('/shorts/');
  }
  
  // Duration
  const durationEl = element.querySelector('.ytd-thumbnail-overlay-time-status-renderer, #text.ytd-thumbnail-overlay-time-status-renderer');
  if (durationEl) {
    metadata.duration = parseDuration(durationEl.textContent.trim());
  }
  
  // Check if live
  const badges = element.querySelectorAll('.badge, .badge-style-type-live-now');
  for (const badge of badges) {
    const text = badge.textContent.toUpperCase();
    if (text.includes('LIVE') || text.includes('UPCOMING')) {
      metadata.isLive = true;
      break;
    }
  }
  
  // Channel
  const channelEl = element.querySelector('#channel-name a, #text.ytd-channel-name a, ytd-channel-name a');
  if (channelEl) {
    metadata.channelName = channelEl.textContent.trim();
    if (channelEl.href) {
      const match = channelEl.href.match(/\/(channel\/|@)([^\/\?]+)/);
      if (match) metadata.channelId = match[2];
    }
  }
  
  // Views
  const metaLine = element.querySelector('#metadata-line, .inline-metadata-item');
  if (metaLine) {
    const text = metaLine.textContent;
    const viewMatch = text.match(/([\d,\.]+)\s*(K|M|B)?\s*views/i);
    if (viewMatch) {
      metadata.views = parseViews(viewMatch[1], viewMatch[2]);
    }
    
    // Upload date
    metadata.uploadDate = parseRelativeDate(text);
  }
  
  return metadata;
}

function parseDuration(text) {
  const parts = text.split(':').map(p => parseInt(p) || 0);
  if (parts.length === 2) {
    return parts[0] * 60 + parts[1];
  } else if (parts.length === 3) {
    return parts[0] * 3600 + parts[1] * 60 + parts[2];
  }
  return 0;
}

function parseViews(num, multiplier) {
  let views = parseFloat(num.replace(/,/g, ''));
  if (multiplier) {
    const mult = { 'K': 1000, 'M': 1000000, 'B': 1000000000 };
    views *= mult[multiplier.toUpperCase()] || 1;
  }
  return views;
}

function parseRelativeDate(text) {
  const now = Date.now();
  const patterns = [
    { regex: /(\d+)\s*second/i, mult: 1000 },
    { regex: /(\d+)\s*minute/i, mult: 60000 },
    { regex: /(\d+)\s*hour/i, mult: 3600000 },
    { regex: /(\d+)\s*day/i, mult: 86400000 },
    { regex: /(\d+)\s*week/i, mult: 604800000 },
    { regex: /(\d+)\s*month/i, mult: 2592000000 },
    { regex: /(\d+)\s*year/i, mult: 31536000000 }
  ];
  
  for (const p of patterns) {
    const match = text.match(p.regex);
    if (match) {
      return now - (parseInt(match[1]) * p.mult);
    }
  }
  return null;
}

function extractVideoId(element) {
  const link = element.querySelector('a#video-title, a#thumbnail, a.yt-simple-endpoint');
  if (link && link.href) {
    const match = link.href.match(/[?&]v=([^&]+)/);
    if (match) return match[1];
    
    const shortsMatch = link.href.match(/\/shorts\/([^\/\?]+)/);
    if (shortsMatch) return shortsMatch[1];
  }
  
  if (element.dataset && element.dataset.videoId) {
    return element.dataset.videoId;
  }
  
  const thumb = element.querySelector('img');
  if (thumb && thumb.src) {
    const match = thumb.src.match(/vi\/([^\/]+)/);
    if (match) return match[1];
  }
  
  return null;
}

function hideVideo(element, reason) {
  element.style.display = 'none';
  element.setAttribute('data-ytrf-hidden', 'true');
  element.setAttribute('data-ytrf-reason', reason);
}

function boostVideo(element, reason) {
  element.style.border = '2px solid #00ff00';
  element.style.boxShadow = '0 0 10px rgba(0, 255, 0, 0.3)';
  element.style.borderRadius = '8px';
  element.setAttribute('data-ytrf-boosted', 'true');
  element.setAttribute('data-ytrf-boost-reason', reason);
}

// UPGRADED: Network request interception for API-level filtering
function interceptNetworkRequests() {
  const originalFetch = window.fetch;
  
  window.fetch = async function(...args) {
    const response = await originalFetch.apply(this, args);
    const url = typeof args[0] === 'string' ? args[0] : args[0].url;
    
    if (url && url.includes('/youtubei/v1/')) {
      const cloned = response.clone();
      
      try {
        const data = await cloned.json();
        
        // Extract video IDs from response and check against watched
        extractAndProcessVideoIds(data);
      } catch (e) {
        // Silent fail
      }
    }
    
    return response;
  };
}

function extractAndProcessVideoIds(data) {
  const ids = [];
  
  function traverse(obj) {
    if (!obj || typeof obj !== 'object') return;
    
    if (obj.videoId && typeof obj.videoId === 'string' && obj.videoId.length === 11) {
      ids.push(obj.videoId);
    }
    
    for (const key in obj) {
      if (obj.hasOwnProperty(key)) {
        traverse(obj[key]);
      }
    }
  }
  
  traverse(data);
  
  // Background process these IDs
  if (ids.length > 0) {
    setTimeout(() => filterVideos(), 500);
  }
}

// UPGRADED: Keyboard shortcuts
function addKeyboardShortcuts() {
  document.addEventListener('keydown', (e) => {
    // Ctrl+Shift+F - Toggle filter
    if (e.ctrlKey && e.shiftKey && e.key === 'F') {
      e.preventDefault();
      toggleFilter();
    }
    
    // Ctrl+Shift+R - Refresh/refilter
    if (e.ctrlKey && e.shiftKey && e.key === 'R') {
      e.preventDefault();
      processedVideos.clear();
      filterVideos();
      showNotification('Feed refiltered!');
    }
    
    // Ctrl+Shift+S - Show stats
    if (e.ctrlKey && e.shiftKey && e.key === 'S') {
      e.preventDefault();
      showStats();
    }
  });
}

async function toggleFilter() {
  settings.hideWatched = !settings.hideWatched;
  
  await chrome.runtime.sendMessage({
    action: 'updateSettings',
    settings: { hideWatched: settings.hideWatched }
  });
  
  if (settings.hideWatched) {
    processedVideos.clear();
    filterVideos();
    showNotification('Filter enabled');
  } else {
    // Show all hidden videos
    document.querySelectorAll('[data-ytrf-hidden]').forEach(el => {
      el.style.display = '';
      el.removeAttribute('data-ytrf-hidden');
    });
    showNotification('Filter disabled');
  }
  
  updateFloatingUI();
}

// UPGRADED: Floating stats UI
function createFloatingUI() {
  const ui = document.createElement('div');
  ui.id = 'ytrf-floating-ui';
  ui.innerHTML = `
    <div class="ytrf-mini">
      <span class="ytrf-icon">🎯</span>
      <span class="ytrf-count">0</span>
    </div>
    <div class="ytrf-expanded" style="display:none">
      <div class="ytrf-header">
        <span>YouTube Filter</span>
        <span class="ytrf-close">×</span>
      </div>
      <div class="ytrf-stats">
        <div class="ytrf-stat">
          <span class="ytrf-label">Hidden:</span>
          <span class="ytrf-value" id="ytrf-hidden-count">0</span>
        </div>
        <div class="ytrf-stat">
          <span class="ytrf-label">Watched:</span>
          <span class="ytrf-value" id="ytrf-watched-count">0</span>
        </div>
        <div class="ytrf-stat">
          <span class="ytrf-label">Status:</span>
          <span class="ytrf-value" id="ytrf-status">Active</span>
        </div>
      </div>
      <div class="ytrf-actions">
        <button id="ytrf-toggle">Toggle Filter</button>
        <button id="ytrf-refresh">Refresh</button>
      </div>
    </div>
  `;
  
  document.body.appendChild(ui);
  
  // Add styles
  const style = document.createElement('style');
  style.textContent = `
    #ytrf-floating-ui {
      position: fixed;
      bottom: 20px;
      right: 20px;
      z-index: 10000;
      font-family: 'Roboto', sans-serif;
    }
    
    .ytrf-mini {
      background: rgba(0, 0, 0, 0.8);
      backdrop-filter: blur(10px);
      color: white;
      padding: 8px 12px;
      border-radius: 20px;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 13px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
      transition: all 0.2s;
    }
    
    .ytrf-mini:hover {
      background: rgba(0, 0, 0, 0.9);
      transform: scale(1.05);
    }
    
    .ytrf-icon {
      font-size: 16px;
    }
    
    .ytrf-count {
      font-weight: bold;
      color: #00ff00;
    }
    
    .ytrf-expanded {
      background: rgba(0, 0, 0, 0.95);
      backdrop-filter: blur(10px);
      color: white;
      padding: 15px;
      border-radius: 10px;
      min-width: 250px;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.5);
    }
    
    .ytrf-header {
      display: flex;
      justify-content: space-between;
      margin-bottom: 12px;
      font-weight: bold;
      font-size: 14px;
    }
    
    .ytrf-close {
      cursor: pointer;
      font-size: 20px;
      line-height: 1;
    }
    
    .ytrf-close:hover {
      color: #ff4444;
    }
    
    .ytrf-stats {
      margin-bottom: 12px;
    }
    
    .ytrf-stat {
      display: flex;
      justify-content: space-between;
      padding: 4px 0;
      font-size: 12px;
    }
    
    .ytrf-label {
      color: #aaa;
    }
    
    .ytrf-value {
      color: #00ff00;
      font-weight: bold;
    }
    
    .ytrf-actions {
      display: flex;
      gap: 8px;
    }
    
    .ytrf-actions button {
      flex: 1;
      background: #333;
      color: white;
      border: none;
      padding: 6px;
      border-radius: 4px;
      cursor: pointer;
      font-size: 11px;
      transition: background 0.2s;
    }
    
    .ytrf-actions button:hover {
      background: #444;
    }
  `;
  document.head.appendChild(style);
  
  // Event listeners
  const mini = ui.querySelector('.ytrf-mini');
  const expanded = ui.querySelector('.ytrf-expanded');
  const close = ui.querySelector('.ytrf-close');
  
  mini.addEventListener('click', () => {
    mini.style.display = 'none';
    expanded.style.display = 'block';
    updateFloatingUI();
  });
  
  close.addEventListener('click', () => {
    expanded.style.display = 'none';
    mini.style.display = 'flex';
  });
  
  ui.querySelector('#ytrf-toggle').addEventListener('click', toggleFilter);
  ui.querySelector('#ytrf-refresh').addEventListener('click', () => {
    processedVideos.clear();
    filterVideos();
  });
}

function updateFloatingUI() {
  const countEl = document.querySelector('.ytrf-count');
  if (countEl) {
    countEl.textContent = hiddenCount;
  }
  
  const hiddenCountEl = document.getElementById('ytrf-hidden-count');
  if (hiddenCountEl) {
    hiddenCountEl.textContent = hiddenCount;
  }
  
  const watchedCountEl = document.getElementById('ytrf-watched-count');
  if (watchedCountEl) {
    watchedCountEl.textContent = watchedVideos.size;
  }
  
  const statusEl = document.getElementById('ytrf-status');
  if (statusEl) {
    statusEl.textContent = settings.hideWatched ? 'Active' : 'Paused';
    statusEl.style.color = settings.hideWatched ? '#00ff00' : '#ffaa00';
  }
}

function showNotification(message) {
  const notif = document.createElement('div');
  notif.textContent = message;
  notif.style.cssText = `
    position: fixed;
    top: 20px;
    right: 20px;
    background: rgba(0, 0, 0, 0.9);
    color: white;
    padding: 12px 20px;
    border-radius: 8px;
    z-index: 10001;
    font-size: 14px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
    animation: slideIn 0.3s ease-out;
  `;
  
  const style = document.createElement('style');
  style.textContent = `
    @keyframes slideIn {
      from {
        transform: translateX(100%);
        opacity: 0;
      }
      to {
        transform: translateX(0);
        opacity: 1;
      }
    }
  `;
  document.head.appendChild(style);
  
  document.body.appendChild(notif);
  
  setTimeout(() => {
    notif.style.animation = 'slideIn 0.3s ease-out reverse';
    setTimeout(() => notif.remove(), 300);
  }, 2000);
}

function showStats() {
  const stats = `
YouTube Recommendation Filter - Statistics

Hidden this session: ${hiddenCount}
Total watched videos: ${watchedVideos.size}
Blocked channels: ${blockedChannels.size}
Boosted channels: ${boostedChannels.size}
Filter status: ${settings.hideWatched ? 'Active' : 'Paused'}

Keyboard Shortcuts:
Ctrl+Shift+F - Toggle filter
Ctrl+Shift+R - Refresh feed
Ctrl+Shift+S - Show stats
  `.trim();
  
  alert(stats);
}

// Listen for messages from background
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'syncHistory') {
    extractWatchHistory();
    sendResponse({ success: true });
  } else if (request.action === 'refilter') {
    processedVideos.clear();
    filterVideos();
    sendResponse({ success: true });
  }
  return true;
});

console.log('YouTube Recommendation Filter v1.1 loaded - Enhanced features active');
console.log('Keyboard shortcuts: Ctrl+Shift+F (toggle), Ctrl+Shift+R (refresh), Ctrl+Shift+S (stats)');
