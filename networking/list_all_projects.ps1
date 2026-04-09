# List all leaf project directories in F:\study\projects

$ErrorActionPreference = 'SilentlyContinue'

$leafDirs = Get-ChildItem -Path 'F:\study\projects' -Directory -Recurse |
    Where-Object { -not (Get-ChildItem -Path $_.FullName -Directory -ErrorAction SilentlyContinue) }

Write-Output "Found $($leafDirs.Count) leaf project directories:"
Write-Output ""

$leafDirs | ForEach-Object {
    Write-Output $_.FullName
}
