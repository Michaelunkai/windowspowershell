<#
.SYNOPSIS
    top100
#>
param([string]$p='.');$ex='\\windows\\|\\program files|\\programdata|system volume information|\$recycle\.bin|\\boot\\|winsxs|driverstore';$f=Get-ChildItem -LiteralPath $p -Recurse -File -Force -ErrorAction SilentlyContinue|?{($_.Attributes -notmatch 'System|Hidden|ReadOnly')-and($_.FullName -notmatch $ex)};$s=@{};$f|%{$d=$_.Directory.FullName;while($d){if($d -notmatch $ex){$s[$d]=($s[$d]+$_.Length)};$d=[IO.Path]::GetDirectoryName($d)}};$dirs=$s.GetEnumerator()|%{[pscustomobject]@{Name=$_.Key;Size=$_.Value;Type='Folder'}};$files=$f|Select @{n='Name';e={$_.FullName}},@{n='Size';e={$_.Length}},@{n='Type';e={'File'}};($files+$dirs)|Sort Size -Desc|Select -First 100 @{n='Name';e={$_.Name}},@{n='SizeGB';e={[math]::Round($_.Size/1GB,3)}},Type|ft -AutoSize
