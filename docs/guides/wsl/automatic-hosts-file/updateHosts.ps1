$hostname = "wsl.local"

################################################################################

$ifconfig = (wsl -- ip -4 addr show eth0 2> $null)
$ipPattern = "((\d+\.?){4})"
$ip = ([regex]"inet $ipPattern").Match($ifconfig).Groups[1].Value
if (-not $ip) {
    exit
}
Write-Host $ip
$hostsPath = "$env:windir/system32/drivers/etc/hosts"
$hosts = (Get-Content -Path $hostsPath -Raw -ErrorAction Ignore)
if ($null -eq $hosts) {
    $hosts = ""
}
$hosts = $hosts.Trim()
$find = "$ipPattern\s+$hostname"
$entry = "$ip $hostname"
if ($hosts -match $find) {
    $hosts = $hosts -replace $find, $entry
} else {
    $hosts = "$hosts`n$entry".Trim()
}
try {
    $temp = "$hostsPath.new"
    New-Item -Path $temp -ItemType File -Force | Out-Null
    Set-Content -Path $temp $hosts
    Move-Item -Path $temp -Destination $hostsPath -Force
} catch {
    Write-Error "cannot update wsl ip"
}