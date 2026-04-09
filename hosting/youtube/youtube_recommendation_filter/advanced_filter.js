// Advanced filtering features for YouTube Recommendation Filter

class AdvancedFilter {
  constructor() {
    this.rules = [];
    this.loadRules();
  }
  
  async loadRules() {
    const stored = await chrome.storage.local.get('advancedRules');
    this.rules = stored.advancedRules || [];
  }
  
  async saveRules() {
    await chrome.storage.local.set({ advancedRules: this.rules });
  }
  
  addRule(rule) {
    this.rules.push({
      id: Date.now(),
      enabled: true,
      ...rule
    });
    this.saveRules();
  }
  
  removeRule(ruleId) {
    this.rules = this.rules.filter(r => r.id !== ruleId);
    this.saveRules();
  }
  
  // Rule: Hide videos by duration
  durationFilter(video, minMinutes, maxMinutes) {
    const duration = this.extractDuration(video);
    if (!duration) return false;
    
    const minutes = duration / 60;
    if (minMinutes && minutes < minMinutes) return true;
    if (maxMinutes && minutes > maxMinutes) return true;
    return false;
  }
  
  // Rule: Hide videos by title keywords
  keywordFilter(video, keywords, mode = 'blacklist') {
    const title = this.extractTitle(video);
    if (!title) return false;
    
    const titleLower = title.toLowerCase();
    const hasKeyword = keywords.some(kw => titleLower.includes(kw.toLowerCase()));
    
    if (mode === 'blacklist') {
      return hasKeyword; // Hide if contains blacklisted keyword
    } else {
      return !hasKeyword; // Hide if doesn't contain whitelisted keyword
    }
  }
  
  // Rule: Hide videos by view count
  viewCountFilter(video, minViews, maxViews) {
    const views = this.extractViewCount(video);
    if (views === null) return false;
    
    if (minViews && views < minViews) return true;
    if (maxViews && views > maxViews) return true;
    return false;
  }
  
  // Rule: Hide videos by age
  ageFilter(video, maxDaysOld) {
    const uploadDate = this.extractUploadDate(video);
    if (!uploadDate) return false;
    
    const now = new Date();
    const daysDiff = (now - uploadDate) / (1000 * 60 * 60 * 24);
    
    return daysDiff > maxDaysOld;
  }
  
  // Rule: Hide shorts
  hideShorts(video) {
    const link = video.querySelector('a#video-title');
    if (!link) return false;
    
    return link.href.includes('/shorts/');
  }
  
  // Rule: Hide livestreams
  hideLivestreams(video) {
    const badges = video.querySelectorAll('.badge');
    for (const badge of badges) {
      if (badge.textContent.includes('LIVE') || badge.textContent.includes('UPCOMING')) {
        return true;
      }
    }
    return false;
  }
  
  // Rule: Quality-based filtering (like/dislike ratio, engagement)
  qualityFilter(video, minEngagementScore) {
    // Engagement = views / (days since upload)
    const views = this.extractViewCount(video);
    const uploadDate = this.extractUploadDate(video);
    
    if (!views || !uploadDate) return false;
    
    const now = new Date();
    const daysSinceUpload = Math.max(1, (now - uploadDate) / (1000 * 60 * 60 * 24));
    const engagementScore = views / daysSinceUpload;
    
    return engagementScore < minEngagementScore;
  }
  
  // Apply all active rules
  shouldHideVideo(video) {
    for (const rule of this.rules) {
      if (!rule.enabled) continue;
      
      try {
        switch (rule.type) {
          case 'duration':
            if (this.durationFilter(video, rule.minMinutes, rule.maxMinutes)) {
              return { hide: true, reason: `Duration filter: ${rule.minMinutes}-${rule.maxMinutes} min` };
            }
            break;
            
          case 'keyword':
            if (this.keywordFilter(video, rule.keywords, rule.mode)) {
              return { hide: true, reason: `Keyword filter: ${rule.keywords.join(', ')}` };
            }
            break;
            
          case 'viewCount':
            if (this.viewCountFilter(video, rule.minViews, rule.maxViews)) {
              return { hide: true, reason: `View count filter: ${rule.minViews}-${rule.maxViews}` };
            }
            break;
            
          case 'age':
            if (this.ageFilter(video, rule.maxDaysOld)) {
              return { hide: true, reason: `Age filter: older than ${rule.maxDaysOld} days` };
            }
            break;
            
          case 'hideShorts':
            if (this.hideShorts(video)) {
              return { hide: true, reason: 'Shorts filter' };
            }
            break;
            
          case 'hideLivestreams':
            if (this.hideLivestreams(video)) {
              return { hide: true, reason: 'Livestream filter' };
            }
            break;
            
          case 'quality':
            if (this.qualityFilter(video, rule.minEngagementScore)) {
              return { hide: true, reason: `Quality filter: low engagement` };
            }
            break;
        }
      } catch (error) {
        console.error('Error applying filter rule:', rule, error);
      }
    }
    
    return { hide: false };
  }
  
  // Extraction helpers
  extractTitle(video) {
    const titleElement = video.querySelector('#video-title');
    return titleElement ? titleElement.textContent.trim() : null;
  }
  
  extractDuration(video) {
    const durationElement = video.querySelector('.ytd-thumbnail-overlay-time-status-renderer');
    if (!durationElement) return null;
    
    const durationText = durationElement.textContent.trim();
    const parts = durationText.split(':').map(p => parseInt(p));
    
    if (parts.length === 2) {
      return parts[0] * 60 + parts[1]; // MM:SS
    } else if (parts.length === 3) {
      return parts[0] * 3600 + parts[1] * 60 + parts[2]; // HH:MM:SS
    }
    
    return null;
  }
  
  extractViewCount(video) {
    const metadataLine = video.querySelector('#metadata-line');
    if (!metadataLine) return null;
    
    const viewText = metadataLine.textContent;
    const match = viewText.match(/([\d,\.]+)\s*(K|M|B)?\s*views/i);
    
    if (!match) return null;
    
    let views = parseFloat(match[1].replace(/,/g, ''));
    const multiplier = match[2];
    
    if (multiplier) {
      switch (multiplier.toUpperCase()) {
        case 'K': views *= 1000; break;
        case 'M': views *= 1000000; break;
        case 'B': views *= 1000000000; break;
      }
    }
    
    return views;
  }
  
  extractUploadDate(video) {
    const metadataLine = video.querySelector('#metadata-line');
    if (!metadataLine) return null;
    
    const dateText = metadataLine.textContent;
    const now = new Date();
    
    // Parse relative dates (e.g., "2 days ago", "1 week ago")
    const patterns = [
      { regex: /(\d+)\s*second/i, multiplier: 1000 },
      { regex: /(\d+)\s*minute/i, multiplier: 60 * 1000 },
      { regex: /(\d+)\s*hour/i, multiplier: 60 * 60 * 1000 },
      { regex: /(\d+)\s*day/i, multiplier: 24 * 60 * 60 * 1000 },
      { regex: /(\d+)\s*week/i, multiplier: 7 * 24 * 60 * 60 * 1000 },
      { regex: /(\d+)\s*month/i, multiplier: 30 * 24 * 60 * 60 * 1000 },
      { regex: /(\d+)\s*year/i, multiplier: 365 * 24 * 60 * 60 * 1000 }
    ];
    
    for (const pattern of patterns) {
      const match = dateText.match(pattern.regex);
      if (match) {
        const value = parseInt(match[1]);
        const offset = value * pattern.multiplier;
        return new Date(now.getTime() - offset);
      }
    }
    
    return null;
  }
  
  // Export rules
  exportRules() {
    return JSON.stringify(this.rules, null, 2);
  }
  
  // Import rules
  importRules(jsonString) {
    try {
      const imported = JSON.parse(jsonString);
      if (Array.isArray(imported)) {
        this.rules = imported;
        this.saveRules();
        return true;
      }
    } catch (error) {
      console.error('Error importing rules:', error);
    }
    return false;
  }
}

// Example usage:
// const filter = new AdvancedFilter();
// filter.addRule({ type: 'duration', minMinutes: 5, maxMinutes: 30 });
// filter.addRule({ type: 'keyword', keywords: ['clickbait', 'MUST WATCH'], mode: 'blacklist' });
// filter.addRule({ type: 'hideShorts', enabled: true });
