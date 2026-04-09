<#
.SYNOPSIS
    renode
#>
winget install -e --id OpenJS.NodeJS.LTS --force --accept-package-agreements --accept-source-agreements; refreshenv; npm config set prefix "$env:APPDATA\npm"; $prefix=(npm config get prefix).Trim(); if(-not $prefix){$prefix="$env:APPDATA\npm"}; $node="C:\Program Files\nodejs"; foreach($p in @($prefix,$node)){ if($env:Path -notlike "*$p*"){ $env:Path="$env:Path;$p" }; $u=[Environment]::GetEnvironmentVariable('Path','User'); if($u -notlike "*$p*"){ [Environment]::SetEnvironmentVariable('Path',"$u;$p",'User') } }; npm i -g npm@latest --force; npm cache clean --force; npm uninstall -g @anthropic-ai/claude-code @google/gemini-cli @qwen-code/qwen-code --force; npm i -g @anthropic-ai/claude-code @google/gemini-cli @qwen-code/qwen-code --force; refreshenv; foreach($cmd in 'claude','gemini','qwen'){ $c=Get-Command $cmd -ErrorAction SilentlyContinue; if($c){ Write-Host "$cmd -> $($c.Source)" } else { Write-Host "$cmd -> NOT FOUND (expected in $prefix)" } }
