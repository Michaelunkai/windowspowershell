<#
.SYNOPSIS
    sshubuntu
#>
$pass="123456"; $user="ubuntu"; $ip="192.168.1.193"; plink.exe -ssh $user@$ip -pw $pass -t "bash --login"
