// Enhanced Popup Script v1.1

document.addEventListener('DOMContentLoaded', () => {
  initTabs();
  loadSettings();
  attachEventListeners();
});

function initTabs() {
  const tabs = document.querySelectorAll('.tab');
  const contents = document.querySelectorAll('.tab-content');
  
  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const target = tab.dataset.tab;
      
      tabs.forEach(t => t.classList.remove('active'));
      contents.forEach(c => c.classList.remove('active'));
      
      tab.classList.add('active');
      document.querySelector(`[data-content="${target}"]`).classList.add('active');
    });
  });
}

async function loadSettings() {
  try {
    const response = await chrome.runtime.sendMessage({ action: 'getSettings' });
    
    if (!response || !response.settings) return;
    
    // Update stats
    document.getElementById('watchedCount').textContent = response.watchedCount || 0;
    
    // Load blocked/boosted counts
    const blockedData = await chrome.storage.local.get('blockedChannels');
    const boostedData = await chrome.storage.local.get('boostedChannels');
    
    document.getElementById('blockedCount').textContent = 
      (blockedData.blockedChannels || []).length;
    document.getElementById('boostedCount').textContent = 
      (boostedData.boostedChannels || []).length;
    
    // Last sync
    if (response.settings.lastSync) {
      const syncDate = new Date(response.settings.lastSync);
      const now = new Date();
      const diffMinutes = Math.floor((now - syncDate) / 60000);
      
      let syncText;
      if (diffMinutes < 1) syncText = 'Now';
      else if (diffMinutes < 60) syncText = `${diffMinutes}m`;
      else if (diffMinutes < 1440) syncText = `${Math.floor(diffMinutes/60)}h`;
      else syncText = `${Math.floor(diffMinutes/1440)}d`;
      
      document.getElementById('lastSync').textContent = syncText;
    }
    
    // Basic settings
    document.getElementById('hideWatched').checked = response.settings.hideWatched ?? true;
    document.getElementById('boostSubscriptions').checked = response.settings.boostSubscriptions ?? true;
    document.getElementById('enableSync').checked = response.settings.enableSync ?? true;
    document.getElementById('watchThreshold').value = response.settings.watchThreshold ?? 50;
    document.getElementById('thresholdValue').textContent = (response.settings.watchThreshold ?? 50) + '%';
    
    // Advanced settings
    document.getElementById('hideShorts').checked = response.settings.hideShorts ?? false;
    document.getElementById('hideLivestreams').checked = response.settings.hideLivestreams ?? false;
    
    const minDuration = response.settings.minDuration ? Math.floor(response.settings.minDuration / 60) : 0;
    const maxDuration = response.settings.maxDuration ? Math.floor(response.settings.maxDuration / 60) : 0;
    
    document.getElementById('minDuration').value = minDuration;
    document.getElementById('maxDuration').value = maxDuration;
    
    if (response.settings.keywordBlacklist && response.settings.keywordBlacklist.length > 0) {
      document.getElementById('keywordBlacklist').value = response.settings.keywordBlacklist.join(', ');
    }
    
  } catch (error) {
    showStatus('Error loading settings', 'error');
  }
}

function attachEventListeners() {
  // Basic toggles
  ['hideWatched', 'boostSubscriptions', 'enableSync'].forEach(id => {
    document.getElementById(id).addEventListener('change', (e) => {
      updateSetting(id, e.target.checked);
    });
  });
  
  // Watch threshold slider
  document.getElementById('watchThreshold').addEventListener('input', (e) => {
    const value = e.target.value;
    document.getElementById('thresholdValue').textContent = value + '%';
  });
  
  document.getElementById('watchThreshold').addEventListener('change', (e) => {
    updateSetting('watchThreshold', parseInt(e.target.value));
  });
  
  // Advanced toggles
  ['hideShorts', 'hideLivestreams'].forEach(id => {
    document.getElementById(id).addEventListener('change', (e) => {
      updateSetting(id, e.target.checked);
    });
  });
  
  // Buttons
  document.getElementById('syncNow').addEventListener('click', syncNow);
  document.getElementById('openYouTube').addEventListener('click', () => {
    chrome.tabs.create({ url: 'https://www.youtube.com' });
  });
  document.getElementById('refilter').addEventListener('click', refilter);
  document.getElementById('saveAdvanced').addEventListener('click', saveAdvanced);
  document.getElementById('clearCache').addEventListener('click', clearCache);
  document.getElementById('exportData').addEventListener('click', exportData);
  document.getElementById('importData').addEventListener('click', importData);
  document.getElementById('openHistory').addEventListener('click', () => {
    chrome.tabs.create({ url: 'https://www.youtube.com/feed/history' });
  });
}

async function updateSetting(key, value) {
  try {
    const settings = {};
    settings[key] = value;
    
    await chrome.runtime.sendMessage({
      action: 'updateSettings',
      settings: settings
    });
    
    showStatus('Setting saved', 'success');
    
    // Reload YouTube tabs
    const tabs = await chrome.tabs.query({ url: "https://www.youtube.com/*" });
    if (tabs.length > 0) {
      tabs.forEach(tab => {
        chrome.tabs.sendMessage(tab.id, { action: 'refilter' }).catch(() => {});
      });
    }
  } catch (error) {
    showStatus('Error saving setting', 'error');
  }
}

async function saveAdvanced() {
  try {
    const minDuration = parseInt(document.getElementById('minDuration').value) || 0;
    const maxDuration = parseInt(document.getElementById('maxDuration').value) || 0;
    const keywordText = document.getElementById('keywordBlacklist').value.trim();
    
    const settings = {
      minDuration: minDuration * 60, // Convert to seconds
      maxDuration: maxDuration * 60,
      keywordBlacklist: keywordText ? keywordText.split(',').map(k => k.trim()).filter(k => k) : []
    };
    
    await chrome.runtime.sendMessage({
      action: 'updateSettings',
      settings: settings
    });
    
    showStatus('Advanced settings saved', 'success');
    
    // Reload YouTube tabs
    const tabs = await chrome.tabs.query({ url: "https://www.youtube.com/*" });
    tabs.forEach(tab => {
      chrome.tabs.sendMessage(tab.id, { action: 'refilter' }).catch(() => {});
    });
  } catch (error) {
    showStatus('Error saving advanced settings', 'error');
  }
}

async function syncNow() {
  showStatus('Syncing...', 'success');
  
  try {
    const tab = await chrome.tabs.create({
      url: 'https://www.youtube.com/feed/history',
      active: false
    });
    
    setTimeout(async () => {
      await chrome.tabs.remove(tab.id);
      await loadSettings();
      showStatus('Sync complete!', 'success');
    }, 5000);
  } catch (error) {
    showStatus('Sync error', 'error');
  }
}

async function refilter() {
  try {
    const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
    if (tabs[0] && tabs[0].url && tabs[0].url.includes('youtube.com')) {
      await chrome.tabs.sendMessage(tabs[0].id, { action: 'refilter' });
      showStatus('Page refiltered', 'success');
    } else {
      showStatus('Open a YouTube page first', 'error');
    }
  } catch (error) {
    showStatus('Error refiltering', 'error');
  }
}

async function clearCache() {
  if (!confirm('Clear ALL filtered videos? This cannot be undone.')) {
    return;
  }
  
  try {
    await chrome.runtime.sendMessage({ action: 'clearWatchedVideos' });
    await loadSettings();
    showStatus('Cache cleared', 'success');
    
    const tabs = await chrome.tabs.query({ url: "https://www.youtube.com/*" });
    tabs.forEach(tab => chrome.tabs.reload(tab.id));
  } catch (error) {
    showStatus('Error clearing cache', 'error');
  }
}

async function exportData() {
  try {
    const data = await chrome.storage.local.get(null);
    const json = JSON.stringify(data, null, 2);
    
    const blob = new Blob([json], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    
    await chrome.downloads.download({
      url: url,
      filename: `youtube-filter-backup-${Date.now()}.json`,
      saveAs: true
    });
    
    showStatus('Data exported', 'success');
  } catch (error) {
    showStatus('Export error', 'error');
  }
}

async function importData() {
  const input = document.createElement('input');
  input.type = 'file';
  input.accept = '.json';
  
  input.onchange = async (e) => {
    const file = e.target.files[0];
    const reader = new FileReader();
    
    reader.onload = async (event) => {
      try {
        const data = JSON.parse(event.target.result);
        await chrome.storage.local.set(data);
        await loadSettings();
        showStatus('Data imported', 'success');
        
        const tabs = await chrome.tabs.query({ url: "https://www.youtube.com/*" });
        tabs.forEach(tab => chrome.tabs.reload(tab.id));
      } catch (error) {
        showStatus('Import error - invalid file', 'error');
      }
    };
    
    reader.readAsText(file);
  };
  
  input.click();
}

function showStatus(message, type) {
  const status = document.getElementById('status');
  status.textContent = message;
  status.className = 'status ' + type;
  status.style.display = 'block';
  
  setTimeout(() => {
    status.style.display = 'none';
  }, 3000);
}
