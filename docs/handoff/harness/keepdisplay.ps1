# Keeps the display on while the play test draws frames (a power request like a video player's; no setting
# changes). Ends by itself after $Minutes.
param([double]$Minutes = 10)
Add-Type @"
using System; using System.Runtime.InteropServices;
public class AwakeDG { [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint f); }
"@
$until = (Get-Date).AddMinutes($Minutes)
while ((Get-Date) -lt $until) {
    [void][AwakeDG]::SetThreadExecutionState([uint32]2147483651)  # continuous | display required | system required
    Start-Sleep -Seconds 30
}
[void][AwakeDG]::SetThreadExecutionState([uint32]2147483648)
