// Performance Optimizer - Caching and Smart Loading
// Injected into enhanced_content.js for better performance

class PerformanceOptimizer {
  constructor() {
    this.cache = new Map();
    this.cacheExpiry = 5 * 60 * 1000; // 5 minutes
    this.batchQueue = [];
    this.batchTimer = null;
    this.stats = {
      cacheHits: 0,
      cacheMisses: 0,
      apiCalls: 0,
      filteredVideos: 0
    };
  }
  
  // Cached video ID check
  async isVideoWatched(videoId) {
    const cached = this.getFromCache(`watched_${videoId}`);
    if (cached !== null) {
      this.stats.cacheHits++;
      return cached;
    }
    
    this.stats.cacheMisses++;
    const response = await chrome.runtime.sendMessage({
      action: 'isVideoWatched',
      videoId: videoId
    });
    
    this.setCache(`watched_${videoId}`, response.watched);
    return response.watched;
  }
  
  // Batch add watched videos
  addWatchedVideoBatch(videoId, metadata) {
    this.batchQueue.push({ videoId, metadata });
    
    // Process batch after 2 seconds of inactivity
    clearTimeout(this.batchTimer);
    this.batchTimer = setTimeout(() => this.processBatch(), 2000);
  }
  
  async processBatch() {
    if (this.batchQueue.length === 0) return;
    
    const batch = [...this.batchQueue];
    this.batchQueue = [];
    
    try {
      await chrome.runtime.sendMessage({
        action: 'addWatchedVideos',
        videoIds: batch.map(v => v.videoId)
      });
      
      // Update cache
      batch.forEach(({ videoId }) => {
        this.setCache(`watched_${videoId}`, true);
      });
      
      console.log(`Processed batch: ${batch.length} videos`);
    } catch (error) {
      console.error('Batch processing error:', error);
    }
  }
  
  // Cache management
  setCache(key, value) {
    this.cache.set(key, {
      value: value,
      expiry: Date.now() + this.cacheExpiry
    });
  }
  
  getFromCache(key) {
    const cached = this.cache.get(key);
    if (!cached) return null;
    
    if (Date.now() > cached.expiry) {
      this.cache.delete(key);
      return null;
    }
    
    return cached.value;
  }
  
  clearCache() {
    this.cache.clear();
  }
  
  // Performance stats
  getStats() {
    return {
      ...this.stats,
      cacheSize: this.cache.size,
      cacheHitRate: this.stats.cacheHits / (this.stats.cacheHits + this.stats.cacheMisses) || 0,
      batchQueueSize: this.batchQueue.length
    };
  }
  
  // Intelligent prefetching
  async prefetchVideos(videoIds) {
    const uncached = videoIds.filter(id => !this.getFromCache(`watched_${id}`));
    
    if (uncached.length === 0) return;
    
    // Batch check uncached videos
    try {
      const promises = uncached.map(id => 
        chrome.runtime.sendMessage({
          action: 'isVideoWatched',
          videoId: id
        })
      );
      
      const results = await Promise.all(promises);
      
      results.forEach((result, index) => {
        this.setCache(`watched_${uncached[index]}`, result.watched);
      });
      
      this.stats.apiCalls += uncached.length;
    } catch (error) {
      console.error('Prefetch error:', error);
    }
  }
  
  // Lazy loading observer
  createLazyObserver(callback) {
    return new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          callback(entry.target);
        }
      });
    }, {
      rootMargin: '50px' // Start loading 50px before visible
    });
  }
}

// Make available globally for enhanced_content.js (future use)
// window.PerformanceOptimizer = PerformanceOptimizer;
