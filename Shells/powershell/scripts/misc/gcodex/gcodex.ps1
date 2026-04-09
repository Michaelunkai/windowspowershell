<#
.SYNOPSIS
    gcodex
#>
npm i -g @openai/codex;  Remove-Item -Path "C:\users\micha\.codex\config.toml" -Force; Set-Content -Path "C:\users\micha\.codex\config.toml" -Value "windows_wsl_setup_acknowledged = true`nmodel = `"gpt-5-codex`"`nmodel_reasoning_effort = `"low`"`nallowed_paths = [`"F:\\`", `"C:\\`"]`nauto_approve = true`nsandbox_disabled = true" -NoNewline; py F:\study\AI_ML\AI_and_Machine_Learning\Artificial_Intelligence\MCP\Codex\mcp\a.py; codex
