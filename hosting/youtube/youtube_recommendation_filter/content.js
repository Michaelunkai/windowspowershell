// YouTube Recommendation Filter - Content Script
console.log('YouTube Recommendation Filter loaded');

let settings = {};
let observer = null;
let processedVideos = new Set();

// Initialize
(async function init() {
  await loadSettings();
  startObserver();
  extractWatchHistory();
  interceptFetch();
  
  // Listen for navigation changes (SPA)
  let lastUrl = location.href;
  new MutationObserver(() => {
    const currentUrl = location.href;
    if (currentUrl !== lastUrl) {
      lastUrl = currentUrl;
      setTimeout(filterVideos, 500);
    }
  }).observe(document, { subtree: true, childList: true });
})();

// Load settings from background
async function loadSettings() {
  try {
    const response = await chrome.runtime.sendMessage({ action: 'getSettings' });
    settings = response.settings;
    console.log('Settings loaded:', settings);
  } catch (error) {
    console.error('Error loading settings:', error);
  }
}

// Start observing DOM changes
function startObserver() {
  if (observer) observer.disconnect();
  
  observer = new MutationObserver((mutations) => {
    filterVideos();
  });
  
  observer.observe(document.body, {
    childList: true,
    subtree: true
  });
}

// Filter videos on the page
async function filterVideos() {
  if (!settings.hideWatched) return;
  
  // Different selectors for different YouTube pages
  const videoSelectors = [
    'ytd-video-renderer',           // Homepage
    'ytd-grid-video-renderer',      // Grid layout
    'ytd-compact-video-renderer',   // Sidebar
    'ytd-rich-item-renderer',       // Rich grid
    'ytd-playlist-video-renderer',  // Playlist
    'ytd-movie-renderer'            // Movies
  ];
  
  for (const selector of videoSelectors) {
    const videos = document.querySelectorAll(selector);
    
    for (const video of videos) {
      try {
        const videoId = extractVideoId(video);
        if (!videoId || processedVideos.has(videoId)) continue;
        
        processedVideos.add(videoId);
        
        // Check if video is watched
        const response = await chrome.runtime.sendMessage({
          action: 'isVideoWatched',
          videoId: videoId
        });
        
        if (response.watched) {
          hideVideo(video);
        } else {
          // Check channel blocking/boosting
          const channelId = extractChannelId(video);
          if (channelId) {
            const blockedResponse = await chrome.runtime.sendMessage({
              action: 'isChannelBlocked',
              channelId: channelId
            });
            
            if (blockedResponse.blocked) {
              hideVideo(video);
            } else {
              const boostedResponse = await chrome.runtime.sendMessage({
                action: 'isChannelBoosted',
                channelId: channelId
              });
              
              if (boostedResponse.boosted) {
                boostVideo(video);
              }
            }
          }
        }
      } catch (error) {
        // Silent fail for individual videos
      }
    }
  }
  
  // Clean up processed videos cache periodically
  if (processedVideos.size > 1000) {
    processedVideos.clear();
  }
}

// Extract video ID from element
function extractVideoId(element) {
  // Try link href
  const link = element.querySelector('a#video-title, a.yt-simple-endpoint');
  if (link) {
    const url = link.href;
    const match = url.match(/[?&]v=([^&]+)/);
    if (match) return match[1];
  }
  
  // Try data attributes
  if (element.dataset && element.dataset.videoId) {
    return element.dataset.videoId;
  }
  
  // Try thumbnail
  const thumbnail = element.querySelector('img');
  if (thumbnail && thumbnail.src) {
    const match = thumbnail.src.match(/vi\/([^\/]+)/);
    if (match) return match[1];
  }
  
  return null;
}

// Extract channel ID from element
function extractChannelId(element) {
  const channelLink = element.querySelector('a.yt-simple-endpoint[href*="/channel/"], a.yt-simple-endpoint[href*="/@"]');
  if (!channelLink) return null;
  
  const href = channelLink.href;
  const channelMatch = href.match(/\/channel\/([^\/\?]+)/);
  if (channelMatch) return channelMatch[1];
  
  const handleMatch = href.match(/\/@([^\/\?]+)/);
  if (handleMatch) return handleMatch[1];
  
  return null;
}

// Hide video element
function hideVideo(element) {
  element.style.display = 'none';
  element.setAttribute('data-ytrf-hidden', 'true');
}

// Boost video visibility
function boostVideo(element) {
  element.style.border = '2px solid #00ff00';
  element.style.boxShadow = '0 0 10px rgba(0, 255, 0, 0.3)';
  element.setAttribute('data-ytrf-boosted', 'true');
}

// Extract watch history from current page
async function extractWatchHistory() {
  // Only on history page
  if (!location.pathname.includes('/feed/history')) return;
  
  const videoIds = [];
  const videos = document.querySelectorAll('ytd-video-renderer');
  
  for (const video of videos) {
    const videoId = extractVideoId(video);
    if (videoId) videoIds.push(videoId);
  }
  
  if (videoIds.length > 0) {
    const response = await chrome.runtime.sendMessage({
      action: 'addWatchedVideos',
      videoIds: videoIds
    });
    console.log(`Synced ${videoIds.length} videos from history`);
  }
}

// Intercept fetch to catch API responses
function interceptFetch() {
  const originalFetch = window.fetch;
  
  window.fetch = async function(...args) {
    const response = await originalFetch.apply(this, args);
    
    // Clone response to read without consuming original
    const clonedResponse = response.clone();
    
    try {
      const url = args[0];
      
      // Check if it's a YouTube API call
      if (typeof url === 'string' && url.includes('/youtubei/v1/')) {
        const data = await clonedResponse.json();
        
        // Extract video IDs from various API responses
        if (data && data.contents) {
          extractVideoIdsFromAPIResponse(data);
        }
      }
    } catch (error) {
      // Silent fail
    }
    
    return response;
  };
}

// Extract video IDs from API response
function extractVideoIdsFromAPIResponse(data) {
  const videoIds = [];
  
  function traverse(obj) {
    if (!obj || typeof obj !== 'object') return;
    
    if (obj.videoId && typeof obj.videoId === 'string' && obj.videoId.length === 11) {
      videoIds.push(obj.videoId);
    }
    
    for (const key in obj) {
      if (obj.hasOwnProperty(key)) {
        traverse(obj[key]);
      }
    }
  }
  
  traverse(data);
  
  if (videoIds.length > 0) {
    // Send to background for processing
    chrome.runtime.sendMessage({
      action: 'addWatchedVideos',
      videoIds: [...new Set(videoIds)] // Remove duplicates
    });
  }
}

// Track video playback
let currentVideoId = null;
let playbackStartTime = null;

setInterval(() => {
  const videoPlayer = document.querySelector('video');
  if (!videoPlayer) return;
  
  const videoId = new URLSearchParams(window.location.search).get('v');
  if (!videoId) return;
  
  if (videoId !== currentVideoId) {
    currentVideoId = videoId;
    playbackStartTime = Date.now();
  }
  
  // If video is playing and we've watched more than threshold
  if (!videoPlayer.paused) {
    const duration = videoPlayer.duration;
    const currentTime = videoPlayer.currentTime;
    const watchPercentage = (currentTime / duration) * 100;
    
    if (watchPercentage >= settings.watchThreshold) {
      chrome.runtime.sendMessage({
        action: 'addWatchedVideo',
        videoId: videoId
      });
    }
  }
}, 5000);

// Listen for messages from background
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'syncHistory') {
    extractWatchHistory();
    sendResponse({ success: true });
  }
  return true;
});

// Add context menu items via injected script
const script = document.createElement('script');
script.src = chrome.runtime.getURL('injected.js');
script.onload = function() {
  this.remove();
};
(document.head || document.documentElement).appendChild(script);

// Re-filter when settings change
chrome.storage.onChanged.addListener((changes, areaName) => {
  if (areaName === 'local') {
    loadSettings().then(() => {
      processedVideos.clear();
      filterVideos();
    });
  }
});

console.log('YouTube Recommendation Filter initialized');
