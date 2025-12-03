# CampusNet_Silent.ps1
# Silent version for automatic startup login

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigFile = Join-Path $ScriptDir "CampusNet_Config.json"

# Load configuration
if (-not (Test-Path $ConfigFile)) {
    exit 1
}

try {
    $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
    $config.Password = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($config.Password))
} catch {
    exit 2
}

# Get network adapter
function Get-Adapter {
    $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | 
                Where-Object { $_.Status -eq 'Up' }
    
    if (-not $adapters) { return $null }
    
    $selectedAdapter = $adapters[0]
    $ipAddress = Get-NetIPAddress -InterfaceAlias $selectedAdapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue
    
    if (-not $ipAddress) { return $null }
    
    return @{
        IP = $ipAddress.IPAddress
        MAC = ($selectedAdapter.MacAddress -replace '[-:]', '').ToUpper()
    }
}

# Test internet connection
function Test-Internet {
    try {
        $request = [System.Net.WebRequest]::Create("http://www.baidu.com")
        $request.Timeout = 3000
        $response = $request.GetResponse()
        $response.Close()
        return $true
    } catch {
        return $false
    }
}

# Main silent logic
$adapterInfo = Get-Adapter
if (-not $adapterInfo) {
    exit 3
}

# Only login if not already connected
if (-not (Test-Internet)) {
    # Build URL
    $userAccountEncoded = "%2C0%2C$($config.Account)"
    $loginURL = "http://10.0.10.252:801/eportal/?c=Portal&a=login&callback=dr1003&login_method=1" +
                "&user_account=$userAccountEncoded" +
                "&user_password=$($config.Password)" +
                "&wlan_user_ip=$($adapterInfo.IP)" +
                "&wlan_user_ipv6=" +
                "&wlan_user_mac=$($adapterInfo.MAC)" +
                "&wlan_ac_ip=10.128.255.129" +
                "&wlan_ac_name=" +
                "&jsVersion=3.3.2" +
                "&v=8366"
    
    try {
        $response = Invoke-RestMethod -Uri $loginURL -Method GET -TimeoutSec 10
        if ($response -match '"result":"1"') {
            # Login successful
            exit 0
        } else {
            # Login failed
            exit 4
        }
    } catch {
        # Network error
        exit 5
    }
} else {
    # Already connected
    exit 0
}