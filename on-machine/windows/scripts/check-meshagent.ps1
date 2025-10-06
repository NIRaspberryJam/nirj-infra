# check-meshagent.ps1
Start-Sleep -Seconds 10

$service = Get-Service -Name "Mesh Agent" -ErrorAction SilentlyContinue

if (-not $service) {
    $url='https://mesh.niraspberryjam.com/agentinvite?c=llOCucdNSOgIqmZERbgSTPH2Q1ydkz3Xre9xt798PIqvo9kJw1swdBCOMyCmAsPi7rpLnS@kv8mprSqLHjnsRFDRNtcE6J2ySV2jbaEcDtxHJlMcXd8U5xs03L3oPzXN2ZJTIOsnoWPgz0YA9qns@IKvN50ssLGf4K2f40EOA4ithJvys@0bn6fCXhqVhipXiGN$$O4O5ZtnIyVk'
    Start-Process $url
}
