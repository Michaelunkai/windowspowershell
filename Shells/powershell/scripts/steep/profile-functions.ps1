# Add these to your PowerShell profile for quick access
# Location: $PROFILE

function steepturbo {
    & "F:\study\shells\powershell\scripts\steep\steep-turbo.ps1"
}

function fsteepturbo {
    & "F:\study\shells\powershell\scripts\steep\fsteep-turbo.ps1"
}

# Aliases
Set-Alias -Name st -Value steepturbo
Set-Alias -Name fst -Value fsteepturbo
