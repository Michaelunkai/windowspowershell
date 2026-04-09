$imageDir = "F:\study\WebBuilding\projects\portfolio-website\public\images\projects"

# TovPlay - Gaming platform with Flask/PostgreSQL
$tovplaySvg = @"
<svg width="800" height="600" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="gaming-grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#6366f1;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#8b5cf6;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="800" height="600" fill="url(#gaming-grad)"/>
  <rect x="50" y="100" width="700" height="400" rx="10" fill="#1a1a2e" opacity="0.9"/>
  <text x="400" y="200" text-anchor="middle" fill="#ffffff" font-size="48" font-family="Arial, sans-serif" font-weight="bold">TovPlay</text>
  <text x="400" y="250" text-anchor="middle" fill="#a5b4fc" font-size="20" font-family="Arial, sans-serif">Full-Stack Gaming Platform</text>
  <text x="400" y="350" text-anchor="middle" fill="#e2e8f0" font-size="16" font-family="monospace">Flask • PostgreSQL • Socket.IO • Docker</text>
  <circle cx="200" cy="450" r="20" fill="#10b981" opacity="0.6"/>
  <circle cx="300" cy="430" r="25" fill="#3b82f6" opacity="0.5"/>
  <circle cx="500" cy="440" r="22" fill="#f59e0b" opacity="0.6"/>
  <circle cx="600" cy="455" r="18" fill="#ef4444" opacity="0.5"/>
</svg>
"@
$tovplaySvg | Out-File -FilePath "$imageDir\tovplay.svg" -Encoding UTF8

# Game Library - Docker/JavaScript
$gameLibrarySvg = @"
<svg width="800" height="600" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="library-grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#10b981;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#059669;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="800" height="600" fill="url(#library-grad)"/>
  <rect x="100" y="120" width="180" height="250" rx="8" fill="#1e293b" opacity="0.8"/>
  <rect x="310" y="120" width="180" height="250" rx="8" fill="#1e293b" opacity="0.8"/>
  <rect x="520" y="120" width="180" height="250" rx="8" fill="#1e293b" opacity="0.8"/>
  <text x="400" y="80" text-anchor="middle" fill="#ffffff" font-size="42" font-family="Arial, sans-serif" font-weight="bold">928 Games Library</text>
  <rect x="110" y="130" width="160" height="160" fill="#10b981" opacity="0.3"/>
  <rect x="320" y="130" width="160" height="160" fill="#3b82f6" opacity="0.3"/>
  <rect x="530" y="130" width="160" height="160" fill="#f59e0b" opacity="0.3"/>
</svg>
"@
$gameLibrarySvg | Out-File -FilePath "$imageDir\game-library.svg" -Encoding UTF8

# Security Scanner - Trivy/Docker
$securitySvg = @"
<svg width="800" height="600" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="security-grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#ef4444;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#dc2626;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="800" height="600" fill="url(#security-grad)"/>
  <path d="M 400 150 L 500 250 L 400 450 L 300 250 Z" fill="#1e293b" opacity="0.9"/>
  <text x="400" y="100" text-anchor="middle" fill="#ffffff" font-size="38" font-family="Arial, sans-serif" font-weight="bold">Container Security Scanner</text>
  <text x="400" y="320" text-anchor="middle" fill="#fecaca" font-size="64" font-family="Arial, sans-serif" font-weight="bold">🛡️</text>
  <text x="400" y="500" text-anchor="middle" fill="#e2e8f0" font-size="16" font-family="monospace">Trivy • CVE Detection • CVSS Scoring</text>
</svg>
"@
$securitySvg | Out-File -FilePath "$imageDir\security-scanner.svg" -Encoding UTF8

# Monitoring - Prometheus/Grafana
$monitoringSvg = @"
<svg width="800" height="600" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="monitor-grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#f59e0b;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#d97706;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="800" height="600" fill="url(#monitor-grad)"/>
  <rect x="50" y="100" width="700" height="400" rx="10" fill="#0f172a" opacity="0.9"/>
  <text x="400" y="80" text-anchor="middle" fill="#ffffff" font-size="36" font-family="Arial, sans-serif" font-weight="bold">Prometheus Monitoring</text>
  <polyline points="100,300 200,250 300,280 400,200 500,240 600,180 700,220" stroke="#f59e0b" stroke-width="4" fill="none"/>
  <polyline points="100,400 200,380 300,360 400,340 500,350 600,320 700,310" stroke="#3b82f6" stroke-width="4" fill="none"/>
  <text x="400" y="550" text-anchor="middle" fill="#cbd5e1" font-size="18" font-family="monospace">99.9% Uptime • Real-Time Metrics</text>
</svg>
"@
$monitoringSvg | Out-File -FilePath "$imageDir\monitoring.svg" -Encoding UTF8

# ArgoCD - GitOps
$argocdSvg = @"
<svg width="800" height="600" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="argocd-grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#8b5cf6;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#7c3aed;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="800" height="600" fill="url(#argocd-grad)"/>
  <circle cx="200" cy="300" r="60" fill="#1e293b" opacity="0.9"/>
  <circle cx="400" cy="300" r="60" fill="#1e293b" opacity="0.9"/>
  <circle cx="600" cy="300" r="60" fill="#1e293b" opacity="0.9"/>
  <line x1="260" y1="300" x2="340" y2="300" stroke="#a78bfa" stroke-width="4"/>
  <line x1="460" y1="300" x2="540" y2="300" stroke="#a78bfa" stroke-width="4"/>
  <text x="400" y="80" text-anchor="middle" fill="#ffffff" font-size="40" font-family="Arial, sans-serif" font-weight="bold">ArgoCD GitOps</text>
  <text x="200" y="310" text-anchor="middle" fill="#a78bfa" font-size="20" font-family="monospace">Git</text>
  <text x="400" y="310" text-anchor="middle" fill="#a78bfa" font-size="20" font-family="monospace">ArgoCD</text>
  <text x="600" y="310" text-anchor="middle" fill="#a78bfa" font-size="20" font-family="monospace">K8s</text>
</svg>
"@
$argocdSvg | Out-File -FilePath "$imageDir\argocd.svg" -Encoding UTF8

# API Gateway
$apiGatewaySvg = @"
<svg width="800" height="600" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="api-grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#06b6d4;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#0891b2;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="800" height="600" fill="url(#api-grad)"/>
  <rect x="300" y="150" width="200" height="300" rx="10" fill="#0f172a" opacity="0.9"/>
  <rect x="100" y="220" width="120" height="60" rx="5" fill="#1e293b"/>
  <rect x="580" y="220" width="120" height="60" rx="5" fill="#1e293b"/>
  <rect x="580" y="320" width="120" height="60" rx="5" fill="#1e293b"/>
  <line x1="220" y1="250" x2="300" y2="250" stroke="#22d3ee" stroke-width="3"/>
  <line x1="500" y1="250" x2="580" y2="250" stroke="#22d3ee" stroke-width="3"/>
  <line x1="500" y1="350" x2="580" y2="350" stroke="#22d3ee" stroke-width="3"/>
  <text x="400" y="100" text-anchor="middle" fill="#ffffff" font-size="36" font-family="Arial, sans-serif" font-weight="bold">API Gateway</text>
  <text x="400" y="300" text-anchor="middle" fill="#22d3ee" font-size="20" font-family="monospace">Rate Limiting • Caching • Auth</text>
</svg>
"@
$apiGatewaySvg | Out-File -FilePath "$imageDir\api-gateway.svg" -Encoding UTF8

Write-Host "Generated 6 project images with tech-specific designs!"
Write-Host "Generating remaining 14 images..."

# Continue with remaining projects using similar patterns...
# For brevity, creating simpler but project-specific remaining images

$remainingProjects = @{
    "log-ai" = @{ title="Log Analysis AI"; color="#ec4899"; tech="ML • Python • ELK" }
    "startupmaster" = @{ title="StartupMaster"; color="#14b8a6"; tech="C# • .NET • Windows" }
    "gitdesk" = @{ title="GitDesk"; color="#f97316"; tech="C# • WPF • Git" }
    "gitit" = @{ title="gitit"; color="#a855f7"; tech="Python • CLI • Git" }
    "openclaw" = @{ title="OpenClaw AI"; color="#6366f1"; tech="TypeScript • Claude • Node.js" }
    "youtube-filter" = @{ title="YouTube Filter"; color="#84cc16"; tech="JavaScript • Browser Extension" }
    "tovplay-frontend" = @{ title="TovPlay Frontend"; color="#f43f5e"; tech="React • Vite • Tailwind" }
    "job-tracker" = @{ title="Job Task Tracker"; color="#0ea5e9"; tech="Node.js • PostgreSQL • React" }
    "win11-monitor" = @{ title="Win11 Monitor"; color="#d946ef"; tech="WebSockets • Chart.js • Node.js" }
    "reddit-aggregator" = @{ title="Reddit Aggregator"; color="#22c55e"; tech="Reddit API • Socket.IO" }
    "claude-news" = @{ title="Claude News"; color="#eab308"; tech="RSS • Cron • Express" }
    "uninstallpro" = @{ title="UninstallPro"; color="#f43f5e"; tech="C# • .NET • Registry API" }
    "game-launcher" = @{ title="Game Launcher Pro"; color="#06b6d4"; tech="C# • WPF • SQLite" }
    "quaddown" = @{ title="QuadDown"; color="#8b5cf6"; tech="Python • Qt • Torrents" }
}

foreach ($project in $remainingProjects.GetEnumerator()) {
    $name = $project.Key
    $data = $project.Value
    
    $svg = @"
<svg width="800" height="600" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad-$name" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:$($data.color);stop-opacity:1" />
      <stop offset="100%" style="stop-color:$($data.color);stop-opacity:0.7" />
    </linearGradient>
  </defs>
  <rect width="800" height="600" fill="url(#grad-$name)"/>
  <rect x="80" y="120" width="640" height="360" rx="15" fill="#0f172a" opacity="0.85"/>
  <text x="400" y="220" text-anchor="middle" fill="#ffffff" font-size="48" font-family="Arial, sans-serif" font-weight="bold">$($data.title)</text>
  <text x="400" y="380" text-anchor="middle" fill="#e2e8f0" font-size="20" font-family="monospace">$($data.tech)</text>
  <rect x="150" y="280" width="120" height="8" rx="4" fill="$($data.color)" opacity="0.6"/>
  <rect x="340" y="280" width="120" height="8" rx="4" fill="$($data.color)" opacity="0.8"/>
  <rect x="530" y="280" width="120" height="8" rx="4" fill="$($data.color)" opacity="0.6"/>
</svg>
"@
    
    $svg | Out-File -FilePath "$imageDir\$name.svg" -Encoding UTF8
    Write-Host "Created: $name.svg"
}

Write-Host "`nGenerated all 20 project-specific images!"
