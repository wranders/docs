# Automatic Hosts File

Developing with WSL is handy, but can get tricky when you need to access it from
the Windows Host, such as accessing a web server.

This task will watch the Event Viewer for when Hyper-V loads network drivers and
run the script. The IPv4 address of the `eth0` interface will then be added to
the Windows `hosts` file at `wsl.local` (or whatever name you choose).

## Script

Much of this was taken from a site I found [^1]. I added the `stderr` null
redirect because the `wsl` command when run in scripts complains about TTY size
and will cause the script to fail.

Since this writes to a location within `$env:windir`, elevated privileges are
required to run this.

The suggested directory to place this is
`%USERPROFILE%\Documents\PowerShell\Scripts` with the file name
`updateHosts.ps1`.

```ps1
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
```

## Task

The following script creates a scheduled task that watches for loading Hyper-V
network drivers.

This script must be run with elevated privileges. The above script is assumed to
be placed in `%USERPROFILE%\Documents\PowerShell\Scripts` and be named
`updateHosts.ps1`. If the script is a different name or in a different location,
change the `$scriptLocation` variable.

This script can be copied and paste inside an elevated PowerShell terminal.

```ps1
$scriptLocation="$env:USERPROFILE\Documents\PowerShell\Scripts\updateHosts.ps1"

################################################################################

$trigger = cimclass MSFT_TaskEventTrigger root/Microsoft/Windows/TaskScheduler `
    | New-CimInstance -ClientOnly

$trigger.Enabled = $true

$trigger.Subscription = @'
<QueryList>
  <Query Id="0" Path="System">
    <Select Path="System">
      *[System[Provider[@Name="Microsoft-Windows-Hyper-V-VmSwitch"] and EventID=102]]
    </Select>
  </Query>
</QueryList>
'@

$trigger.Delay = "PT5S" # 5 Seconds to allow WSL some time to initialize

$actionParams =  @{
    Execute  = "powershell.exe"
    Argument = "-WindowStyle hidden -File $scriptLocation"
}
$action    = New-ScheduledTaskAction @actionParams

$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType ServiceAccount `
    -RunLevel Highest

$settings  = New-ScheduledTaskSettingsSet

$taskParams = @{
    TaskName    = "WSL Set Hosts File IP"
    Description = "Set WSL IP address in hosts file"
    TaskPath    = "\Event Viewer Tasks\"
    Action      = $action
    Principal   = $principal
    Settings    = $settings
    Trigger     = $trigger
}

Register-ScheduledTask @taskParams
```

## Wrap-Up

Now shutdown and restart WSL.

```powershell
wsl --shutdown
```

```powershell
C:> bash -c "ip -4 addr show eth0"
Sleeping for 1 second to let systemd settle
4: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    inet 172.18.79.2/20 brd 172.18.79.255 scope global eth0
       valid_lft forever preferred_lft forever
```

!!! tip "Running `bash` will cause WSL to start if it's not running."

```powershell
C:> ping wsl.local

Pinging wsl.local [172.18.79.2] with 32 bytes of data:
Reply from 172.18.79.2: bytes=32 time<1ms TTL=64
Reply from 172.18.79.2: bytes=32 time<1ms TTL=64
Reply from 172.18.79.2: bytes=32 time<1ms TTL=64
Reply from 172.18.79.2: bytes=32 time<1ms TTL=64

Ping statistics for 172.18.79.2:
    Packets: Sent = 4, Received = 4, Lost = 0 (0% loss),
Approximate round trip times in milli-seconds:
    Minimum = 0ms, Maximum = 0ms, Average = 0ms
```

You'll see that the IP addresses match.

[^1]: [https://abdus.dev/posts/fixing-wsl2-localhost-access-issue/](https://abdus.dev/posts/fixing-wsl2-localhost-access-issue/){target=_blank rel="nofollow noopener noreferrer"}
