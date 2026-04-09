// Injected script for YouTube Recommendation Filter
// Runs in page context (has access to YouTube's JS)

(function() {
  'use strict';
  
  console.log('YouTube Recommendation Filter - Injected script loaded');
  
  // Add custom context menu to video elements
  document.addEventListener('contextmenu', function(e) {
    const videoElement = e.target.closest('ytd-video-renderer, ytd-grid-video-renderer, ytd-compact-video-renderer, ytd-rich-item-renderer');
    if (videoElement) {
      // Store reference for popup menu
      window.ytRfContextVideo = videoElement;
    }
  }, true);
  
  // Intercept YouTube's internal API for more aggressive filtering
  if (window.ytInitialData) {
    console.log('YouTube initial data detected');
  }
  
})();
