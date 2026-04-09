// YouTube Recommendation Filter - Background Service Worker
let watchedVideos = new Set();
let blockedChannels = new Set();
let boostedChannels = new Set();
let settings = {
  hideWatched: true,
  watchThreshold: 50, // percentage watched to count as "seen"
  boostSubscriptions: true,
  enableSync: true,
  lastSync: null
};

// Initialize storage
chrome.runtime.onInstalled.addListener(async () => {
  console.log('YouTube Recommendation Filter installed');
  await loadFromStorage();
  await syncWatchHistory();
});

// Load data from storage
async function loadFromStorage() {
  try {
    const data = await chrome.storage.local.get(['watchedVideos', 'blockedChannels', 'boostedChannels', 'settings']);
    
    if (data.watchedVideos) {
      watchedVideos = new Set(data.watchedVideos);
    }
    if (data.blockedChannels) {
      blockedChannels = new Set(data.blockedChannels);
    }
    if (data.boostedChannels) {
      boostedChannels = new Set(data.boostedChannels);
    }
    if (data.settings) {
      settings = { ...settings, ...data.settings };
    }
    
    console.log(`Loaded ${watchedVideos.size} watched videos`);
  } catch (error) {
    console.error('Error loading from storage:', error);
  }
}

// Save data to storage
async function saveToStorage() {
  try {
    await chrome.storage.local.set({
      watchedVideos: Array.from(watchedVideos),
      blockedChannels: Array.from(blockedChannels),
      boostedChannels: Array.from(boostedChannels),
      settings: settings
    });
  } catch (error) {
    console.error('Error saving to storage:', error);
  }
}

// Sync watch history from YouTube
async function syncWatchHistory() {
  console.log('Starting watch history sync...');
  settings.lastSync = Date.now();
  await saveToStorage();
  
  // Send message to content script to extract watch history
  chrome.tabs.query({ url: "https://www.youtube.com/*" }, (tabs) => {
    tabs.forEach(tab => {
      chrome.tabs.sendMessage(tab.id, { action: 'syncHistory' });
    });
  });
}

// Listen for messages from content script
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'addWatchedVideo') {
    watchedVideos.add(request.videoId);
    saveToStorage();
    sendResponse({ success: true });
  } 
  else if (request.action === 'addWatchedVideos') {
    request.videoIds.forEach(id => watchedVideos.add(id));
    saveToStorage();
    console.log(`Added ${request.videoIds.length} watched videos`);
    sendResponse({ success: true, total: watchedVideos.size });
  }
  else if (request.action === 'isVideoWatched') {
    sendResponse({ watched: watchedVideos.has(request.videoId) });
  }
  else if (request.action === 'getSettings') {
    sendResponse({ settings, watchedCount: watchedVideos.size });
  }
  else if (request.action === 'updateSettings') {
    settings = { ...settings, ...request.settings };
    saveToStorage();
    sendResponse({ success: true });
  }
  else if (request.action === 'blockChannel') {
    blockedChannels.add(request.channelId);
    saveToStorage();
    sendResponse({ success: true });
  }
  else if (request.action === 'boostChannel') {
    boostedChannels.add(request.channelId);
    saveToStorage();
    sendResponse({ success: true });
  }
  else if (request.action === 'isChannelBlocked') {
    sendResponse({ blocked: blockedChannels.has(request.channelId) });
  }
  else if (request.action === 'isChannelBoosted') {
    sendResponse({ boosted: boostedChannels.has(request.channelId) });
  }
  else if (request.action === 'clearWatchedVideos') {
    watchedVideos.clear();
    saveToStorage();
    sendResponse({ success: true });
  }
  
  return true; // Keep message channel open for async response
});

// Auto-sync every 30 minutes
setInterval(() => {
  if (settings.enableSync) {
    syncWatchHistory();
  }
}, 30 * 60 * 1000);

// Intercept YouTube API requests (manifest v3 approach)
chrome.webRequest.onBeforeRequest.addListener(
  (details) => {
    // Log API calls for debugging
    if (details.url.includes('/youtubei/v1/')) {
      console.log('YouTube API call:', details.url);
    }
  },
  { urls: ["https://www.youtube.com/youtubei/v1/*"] }
);
