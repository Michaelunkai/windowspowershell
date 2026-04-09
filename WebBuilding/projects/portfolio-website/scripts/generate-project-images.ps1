$projects = @(
    "tovplay",
    "game-library",
    "security-scanner",
    "monitoring",
    "argocd",
    "api-gateway",
    "log-ai",
    "startupmaster",
    "gitdesk",
    "gitit",
    "openclaw",
    "youtube-filter",
    "tovplay-frontend",
    "job-tracker",
    "win11-monitor",
    "reddit-aggregator",
    "claude-news",
    "uninstallpro",
    "game-launcher",
    "quaddown"
)

$colors = @(
    "#3b82f6", "#10b981", "#ef4444", "#f59e0b", "#8b5cf6",
    "#06b6d4", "#ec4899", "#14b8a6", "#f97316", "#a855f7",
    "#6366f1", "#84cc16", "#f43f5e", "#0ea5e9", "#d946ef",
    "#22c55e", "#eab308", "#f43f5e", "#06b6d4", "#8b5cf6"
)

$imageDir = "F:\study\WebBuilding\projects\portfolio-website\public\images\projects"
if (-not (Test-Path $imageDir)) {
    New-Item -ItemType Directory -Path $imageDir -Force | Out-Null
}

for ($i = 0; $i -lt $projects.Length; $i++) {
    $projectName = $projects[$i]
    $color = $colors[$i % $colors.Length]
    $fileName = "$imageDir\$projectName.svg"
    
    $svgContent = @"
<svg width="600" height="400" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad$i" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:$color;stop-opacity:1" />
      <stop offset="100%" style="stop-color:$color;stop-opacity:0.6" />
    </linearGradient>
  </defs>
  <rect width="600" height="400" fill="url(#grad$i)"/>
  <text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" fill="white" font-size="32" font-family="Arial, sans-serif" font-weight="bold">$($projectName.ToUpper())</text>
</svg>
"@
    
    $svgContent | Out-File -FilePath $fileName -Encoding UTF8
    Write-Host "Created: $fileName"
}

Write-Host "`nGenerated $($projects.Length) project placeholder images!"
