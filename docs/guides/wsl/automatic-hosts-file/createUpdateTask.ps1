$scriptLocation="$env:USERPROFILE\Documents\PowerShell\Scripts\updateHosts.ps1"

################################################################################

$trigger = Get-CimClass MSFT_TaskEventTrigger root/Microsoft/Windows/TaskScheduler `
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