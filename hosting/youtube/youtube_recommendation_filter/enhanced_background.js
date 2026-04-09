// Enhanced Background Service Worker v1.1
// Smart recommendation tracking with machine learning-like patterns

console.log('[YTRF] Background service worker starting...');

let watchedVideos = new Set();
let blockedChannels = new Set();
let boostedChannels = new Set();
let videoMetadata = new Map(); // Store metadata for ML analysis
let watchPatterns = new Map(); // Track watching patterns
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
  diversityMode: false,
  lastSync: null
};

// Initialize on install
chrome.runtime.onInstalled.addListener(async () => {
  try {
    console.log('[YTRF] Installing v1.1...');
    await loadFromStorage();
    await syncWatchHistory();
    startPeriodicSync();
    createContextMenus();
    console.log('[YTRF] Installation complete');
  } catch (error) {
    console.error('[YTRF] Installation error:', error);
  }
});

// Load on startup
chrome.runtime.onStartup.addListener(async () => {
  try {
    console.log('[YTRF] Startup initiated...');
    await loadFromStorage();
    startPeriodicSync();
    console.log('[YTRF] Startup complete');
  } catch (error) {
    console.error('[YTRF] Startup error:', error);
  }
});

// Load all data from storage
async function loadFromStorage() {
  try {
    const data = await chrome.storage.local.get([
      'watchedVideos',
      'blockedChannels', 
      'boostedChannels',
      'videoMetadata',
      'watchPatterns',
      'settings'
    ]);
    
    if (data.watchedVideos) {
      watchedVideos = new Set(data.watchedVideos);
    }
    
    if (data.blockedChannels) {
      blockedChannels = new Set(data.blockedChannels);
    }
    
    if (data.boostedChannels) {
      boostedChannels = new Set(data.boostedChannels);
    }
    
    if (data.videoMetadata) {
      videoMetadata = new Map(Object.entries(data.videoMetadata));
    }
    
    if (data.watchPatterns) {
      watchPatterns = new Map(Object.entries(data.watchPatterns));
    }
    
    if (data.settings) {
      settings = { ...settings, ...data.settings };
    }
    
    console.log(`Loaded: ${watchedVideos.size} watched, ${blockedChannels.size} blocked, ${boostedChannels.size} boosted`);
  } catch (error) {
    console.error('Error loading from storage:', error);
  }
}

// Save to storage with debouncing
let saveTimeout;
async function saveToStorage() {
  clearTimeout(saveTimeout);
  saveTimeout = setTimeout(async () => {
    try {
      await chrome.storage.local.set({
        watchedVideos: Array.from(watchedVideos),
        blockedChannels: Array.from(blockedChannels),
        boostedChannels: Array.from(boostedChannels),
        videoMetadata: Object.fromEntries(videoMetadata),
        watchPatterns: Object.fromEntries(watchPatterns),
        settings: settings
      });
    } catch (error) {
      console.error('Error saving to storage:', error);
    }
  }, 1000);
}

// Sync watch history from YouTube
async function syncWatchHistory() {
  console.log('Starting watch history sync...');
  settings.lastSync = Date.now();
  await saveToStorage();
  
  // Notify content scripts
  const tabs = await chrome.tabs.query({ url: "https://www.youtube.com/*" });
  tabs.forEach(tab => {
    chrome.tabs.sendMessage(tab.id, { action: 'syncHistory' }).catch(() => {});
  });
}

// Start periodic auto-sync
function startPeriodicSync() {
  if (settings.enableSync) {
    setInterval(() => {
      if (settings.enableSync) {
        syncWatchHistory();
      }
    }, 30 * 60 * 1000); // Every 30 minutes
  }
}

// Enhanced message handling
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  handleMessage(request, sender, sendResponse);
  return true; // Keep channel open for async
});

async function handleMessage(request, sender, sendResponse) {
  try {
    switch (request.action) {
      case 'addWatchedVideo':
        watchedVideos.add(request.videoId);
        
        // Store metadata if provided
        if (request.metadata) {
          videoMetadata.set(request.videoId, {
            ...request.metadata,
            watchedAt: Date.now()
          });
        }
        
        // Update watch patterns for ML-like recommendations
        if (request.metadata && request.metadata.channelId) {
          updateWatchPatterns(request.metadata.channelId);
        }
        
        await saveToStorage();
        sendResponse({ success: true });
        break;
        
      case 'addWatchedVideos':
        let added = 0;
        for (const videoId of request.videoIds) {
          if (!watchedVideos.has(videoId)) {
            watchedVideos.add(videoId);
            added++;
          }
        }
        
        await saveToStorage();
        console.log(`Added ${added} new watched videos`);
        sendResponse({ success: true, added: added, total: watchedVideos.size });
        break;
        
      case 'isVideoWatched':
        sendResponse({ watched: watchedVideos.has(request.videoId) });
        break;
        
      case 'getSettings':
        sendResponse({
          settings: settings,
          watchedCount: watchedVideos.size,
          blockedCount: blockedChannels.size,
          boostedCount: boostedChannels.size
        });
        break;
        
      case 'updateSettings':
        settings = { ...settings, ...request.settings };
        await saveToStorage();
        
        // Notify all YouTube tabs to refilter
        const tabs = await chrome.tabs.query({ url: "https://www.youtube.com/*" });
        tabs.forEach(tab => {
          chrome.tabs.sendMessage(tab.id, { action: 'refilter' }).catch(() => {});
        });
        
        sendResponse({ success: true });
        break;
        
      case 'blockChannel':
        blockedChannels.add(request.channelId);
        if (request.channelName) {
          // Store channel name for reference
        }
        await saveToStorage();
        sendResponse({ success: true });
        break;
        
      case 'boostChannel':
        boostedChannels.add(request.channelId);
        if (request.channelName) {
          // Store channel name for reference
        }
        await saveToStorage();
        sendResponse({ success: true });
        break;
        
      case 'isChannelBlocked':
        sendResponse({ blocked: blockedChannels.has(request.channelId) });
        break;
        
      case 'isChannelBoosted':
        sendResponse({ boosted: boostedChannels.has(request.channelId) });
        break;
        
      case 'clearWatchedVideos':
        watchedVideos.clear();
        videoMetadata.clear();
        watchPatterns.clear();
        await saveToStorage();
        sendResponse({ success: true });
        break;
        
      case 'getRecommendations':
        // ML-like recommendation engine
        const recommendations = generateSmartRecommendations();
        sendResponse({ recommendations });
        break;
        
      case 'reportVideoInteraction':
        // Track user interactions for better filtering
        handleVideoInteraction(request.videoId, request.interaction);
        sendResponse({ success: true });
        break;
        
      default:
        sendResponse({ error: 'Unknown action' });
    }
  } catch (error) {
    console.error('Message handling error:', error);
    sendResponse({ error: error.message });
  }
}

// Update watch patterns for ML-like analysis
function updateWatchPatterns(channelId) {
  const pattern = watchPatterns.get(channelId) || {
    watchCount: 0,
    lastWatched: null,
    avgWatchDuration: 0,
    totalWatchTime: 0
  };
  
  pattern.watchCount++;
  pattern.lastWatched = Date.now();
  
  watchPatterns.set(channelId, pattern);
}

// Generate smart recommendations based on watch history
function generateSmartRecommendations() {
  // Analyze watch patterns
  const channelPreferences = new Map();
  
  for (const [channelId, pattern] of watchPatterns.entries()) {
    const score = calculateChannelScore(pattern);
    channelPreferences.set(channelId, score);
  }
  
  // Sort by score
  const sorted = Array.from(channelPreferences.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10);
  
  return {
    topChannels: sorted.map(([id, score]) => ({ channelId: id, score })),
    totalAnalyzed: watchPatterns.size,
    confidence: watchPatterns.size > 10 ? 'high' : watchPatterns.size > 5 ? 'medium' : 'low'
  };
}

function calculateChannelScore(pattern) {
  let score = 0;
  
  // Frequency bonus
  score += pattern.watchCount * 10;
  
  // Recency bonus
  if (pattern.lastWatched) {
    const daysSince = (Date.now() - pattern.lastWatched) / (1000 * 60 * 60 * 24);
    if (daysSince < 7) score += 50;
    else if (daysSince < 30) score += 25;
  }
  
  // Watch duration bonus
  if (pattern.avgWatchDuration > 0.7) score += 30; // Watched >70%
  
  return score;
}

function handleVideoInteraction(videoId, interaction) {
  // Track interactions like: clicked, watched, skipped, liked
  // This data can be used for future ML-based filtering
  const metadata = videoMetadata.get(videoId) || {};
  
  if (!metadata.interactions) {
    metadata.interactions = [];
  }
  
  metadata.interactions.push({
    type: interaction,
    timestamp: Date.now()
  });
  
  videoMetadata.set(videoId, metadata);
  saveToStorage();
}

// Intercept web requests (optional - for advanced filtering)
chrome.webRequest.onBeforeRequest.addListener(
  (details) => {
    // Could modify requests here if needed
    // For now, just log for debugging
    if (details.url.includes('/youtubei/v1/browse') || 
        details.url.includes('/youtubei/v1/next')) {
      console.log('YouTube API request intercepted:', details.url);
    }
  },
  { urls: ["https://www.youtube.com/youtubei/v1/*"] }
);

// Context menu integration (for easy channel blocking/boosting)
function createContextMenus() {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: 'ytrf-block-channel',
      title: 'Block this YouTube channel',
      contexts: ['link', 'page'],
      documentUrlPatterns: ['https://www.youtube.com/*']
    });
    
    chrome.contextMenus.create({
      id: 'ytrf-boost-channel',
      title: 'Boost this YouTube channel',
      contexts: ['link', 'page'],
      documentUrlPatterns: ['https://www.youtube.com/*']
    });
  });
}

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId === 'ytrf-block-channel' || info.menuItemId === 'ytrf-boost-channel') {
    // Send message to content script to extract channel ID
    const response = await chrome.tabs.sendMessage(tab.id, {
      action: 'getChannelFromContext'
    }).catch(() => null);
    
    if (response && response.channelId) {
      if (info.menuItemId === 'ytrf-block-channel') {
        blockedChannels.add(response.channelId);
        console.log('Blocked channel:', response.channelId);
      } else {
        boostedChannels.add(response.channelId);
        console.log('Boosted channel:', response.channelId);
      }
      
      await saveToStorage();
      
      // Reload page to apply changes
      chrome.tabs.reload(tab.id);
    }
  }
});

console.log('[YTRF] YouTube Recommendation Filter v1.1 - Enhanced background service loaded');

// Global error handler
self.addEventListener('error', (event) => {
  console.error('[YTRF] Service worker error:', event.error);
});

self.addEventListener('unhandledrejection', (event) => {
  console.error('[YTRF] Unhandled promise rejection:', event.reason);
});
