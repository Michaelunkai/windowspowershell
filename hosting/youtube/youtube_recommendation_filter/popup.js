// YouTube Recommendation Filter - Popup Script

document.addEventListener('DOMContentLoaded', async () => {
  await loadSettings();
  attachEventListeners();
});

async function loadSettings() {
  try {
    const response = await chrome.runtime.sendMessage({ action: 'getSettings' });
    
    // Update UI
    document.getElementById('hideWatched').checked = response.settings.hideWatched;
    document.getElementById('boostSubscriptions').checked = response.settings.boostSubscriptions;
    document.getElementById('enableSync').checked = response.settings.enableSync;
    document.getElementById('watchThreshold').value = response.settings.watchThreshold;
    document.getElementById('thresholdValue').textContent = response.settings.watchThreshold + '%';
    
    // Update stats
    document.getElementById('watchedCount').textContent = response.watchedCount.toLocaleString();
    
    if (response.settings.lastSync) {
      const syncDate = new Date(response.settings.lastSync);
      const now = new Date();
      const diffMinutes = Math.floor((now - syncDate) / 60000);
      
      if (diffMinutes < 1) {
        document.getElementById('lastSync').textContent = 'Just now';
      } else if (diffMinutes < 60) {
        document.getElementById('lastSync').textContent = diffMinutes + 'm ago';
      } else {
        const diffHours = Math.floor(diffMinutes / 60);
        document.getElementById('lastSync').textContent = diffHours + 'h ago';
      }
    }
  } catch (error) {
    showStatus('Error loading settings', true);
  }
}

function attachEventListeners() {
  // Toggle switches
  document.getElementById('hideWatched').addEventListener('change', (e) => {
    updateSetting('hideWatched', e.target.checked);
  });
  
  document.getElementById('boostSubscriptions').addEventListener('change', (e) => {
    updateSetting('boostSubscriptions', e.target.checked);
  });
  
  document.getElementById('enableSync').addEventListener('change', (e) => {
    updateSetting('enableSync', e.target.checked);
  });
  
  // Slider
  document.getElementById('watchThreshold').addEventListener('input', (e) => {
    const value = e.target.value;
    document.getElementById('thresholdValue').textContent = value + '%';
    updateSetting('watchThreshold', parseInt(value));
  });
  
  // Buttons
  document.getElementById('syncNow').addEventListener('click', syncNow);
  document.getElementById('openHistory').addEventListener('click', openHistory);
  document.getElementById('clearCache').addEventListener('click', clearCache);
}

async function updateSetting(key, value) {
  try {
    const settings = {};
    settings[key] = value;
    
    await chrome.runtime.sendMessage({
      action: 'updateSettings',
      settings: settings
    });
    
    showStatus('Settings saved');
    
    // Reload current YouTube tabs
    const tabs = await chrome.tabs.query({ url: "https://www.youtube.com/*" });
    tabs.forEach(tab => {
      chrome.tabs.reload(tab.id);
    });
  } catch (error) {
    showStatus('Error saving settings', true);
  }
}

async function syncNow() {
  showStatus('Syncing watch history...');
  
  try {
    // Open history page in background
    const tab = await chrome.tabs.create({
      url: 'https://www.youtube.com/feed/history',
      active: false
    });
    
    // Wait for page to load then close
    setTimeout(async () => {
      await chrome.tabs.remove(tab.id);
      await loadSettings();
      showStatus('Sync complete!');
    }, 5000);
  } catch (error) {
    showStatus('Error syncing', true);
  }
}

function openHistory() {
  chrome.tabs.create({
    url: 'https://www.youtube.com/feed/history'
  });
}

async function clearCache() {
  if (!confirm('Clear all filtered videos? This cannot be undone.')) {
    return;
  }
  
  try {
    await chrome.runtime.sendMessage({ action: 'clearWatchedVideos' });
    await loadSettings();
    showStatus('Cache cleared');
    
    // Reload YouTube tabs
    const tabs = await chrome.tabs.query({ url: "https://www.youtube.com/*" });
    tabs.forEach(tab => {
      chrome.tabs.reload(tab.id);
    });
  } catch (error) {
    showStatus('Error clearing cache', true);
  }
}

function showStatus(message, isError = false) {
  const status = document.getElementById('status');
  status.textContent = message;
  status.style.display = 'block';
  
  if (isError) {
    status.classList.add('error');
  } else {
    status.classList.remove('error');
  }
  
  setTimeout(() => {
    status.style.display = 'none';
  }, 3000);
}
