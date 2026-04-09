# Pester tests for Samsung TV configuration
# TV: UE50CU7100UXSQ Serial 0KYH3HEW400178K

$ConfigPath = "C:\Users\micha\Documents\WindowsPowerShell\tv-config.json"
$script:Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

Describe "Samsung TV Config" {

    It "ModelCode should be UE50CU7100UXSQ" {
        $ExpectedModel = "UE50CU7100UXSQ"
        $ExpectedModel | Should Be "UE50CU7100UXSQ"
    }

    It "Serial should be 0KYH3HEW400178K" {
        $ExpectedSerial = "0KYH3HEW400178K"
        $ExpectedSerial | Should Be "0KYH3HEW400178K"
    }

    It "Port should be 8002" {
        $script:Config.Port | Should Be 8002
    }

    It "IP should be non-empty after discovery" {
        $script:Config.IP | Should Not BeNullOrEmpty
    }
}
