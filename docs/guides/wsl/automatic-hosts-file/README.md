# Automatic Hosts File

Developing with WSL is handy, but can get tricky when you need to access it from
the Windows Host, such as accessing a web server.

This task will watch the Event Viewer for when Hyper-V loads network drivers and
run the `updateHosts.ps1` script. The IPv4 address of the `eth0` interface will
then be added to the Windows `hosts` file at `wsl.local` (or whatever name you
choose).

## Script

Much of this was taken from a site I found [^1]. I added the `stderr` null
redirect because the `wsl` command when run in scripts complains about TTY size
and will cause the script to fail.

Since this writes to a location within `#!powershell $env:windir`, elevated
privileges are required to run this.

The suggested directory to place this is
`#!powershell $env:USERPROFILE\Documents\PowerShell\Scripts` with the file name
`updateHosts.ps1`.

```powershell title="updateHosts.ps1"
--8<-- "docs/guides/wsl/automatic-hosts-file/updateHosts.ps1"
```

## Task

The following script creates a scheduled task that watches for loading Hyper-V
network drivers.

This script must be run with elevated privileges. The above script is assumed to
be placed in `#!powershell $env:USERPROFILE\Documents\PowerShell\Scripts` and be
named `updateHosts.ps1`. If the script is a different name or in a different
location, change the `#!powershell $scriptLocation` variable.

This script can be copied and paste inside an elevated PowerShell terminal.

```powershell title="createUpdateTask.ps1"
--8<-- "docs/guides/wsl/automatic-hosts-file/createUpdateTask.ps1"
```

!!! info "Trigger Delay Format"
    Event trigger delays are expressed as a string starting with the letter `P`.
    `T` delimits date and time portions of the string. For more information,
    refer to the Task Scheduler's `EventTrigger.Delay` property
    documentation[^2].

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
[^2]: [https://docs.microsoft.com/en-us/windows/win32/taskschd/eventtrigger-delay](https://docs.microsoft.com/en-us/windows/win32/taskschd/eventtrigger-delay){target=_blank rel="nofollow noopener noreferrer"}
