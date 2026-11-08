# A second Studio on the real place, kept minimised and never activated, so the temporary plugin (Plugins\DGPass.lua)
# runs without the screen. Prints the [DGPASS] lines from that Studio's log, then closes only that Studio.
param([int]$Seconds = 240, [string]$Until = "read done")
$ErrorActionPreference = "Continue"
$placeId = "130650608236392"
$universeId = "10767766818"
$studio = (Get-ChildItem (Join-Path $env:LOCALAPPDATA "Roblox\Versions") -Recurse -Filter "RobloxStudioBeta.exe" |
    Sort-Object LastWriteTime | Select-Object -Last 1).FullName
$logs = Join-Path $env:LOCALAPPDATA "Roblox\logs"

Add-Type -Namespace DGPass -Name Win -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr h, int cmd);
[DllImport("user32.dll")] public static extern bool IsIconic(System.IntPtr h);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(System.IntPtr h);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(System.IntPtr h, out uint pid);
public delegate bool EnumProc(System.IntPtr h, System.IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, System.IntPtr l);
public static void MinimiseAll(uint target) {
    EnumWindows(delegate(System.IntPtr h, System.IntPtr l) {
        uint pid; GetWindowThreadProcessId(h, out pid);
        // SW_SHOWMINNOACTIVE: minimised, and the window in front stays in front
        if (pid == target && IsWindowVisible(h) && !IsIconic(h)) { ShowWindow(h, 7); }
        return true;
    }, System.IntPtr.Zero);
}
'@

# The audio mute from the test runner, so a play test here never sounds over the user's own game.
$runner = Get-Content "C:\Users\negru\AppData\Local\Temp\claude\C--Users-negru-Documents-Lgame\c9664119-1249-48f1-be93-87ba746b4170\scratchpad\harness\run.ps1" -Raw
$code = ([regex]::Match($runner, "(?s)(using System;\s+using System\.Collections\.Generic;.*?namespace DGEHAudio.*?)\r?\n'@")).Groups[1].Value
if ($code) { Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue }

function Family {
    param([int]$Root)
    $all = @(Get-CimInstance Win32_Process -Filter "Name='RobloxStudioBeta.exe'")
    $ids = @($Root)
    $grew = $true
    while ($grew) {
        $grew = $false
        foreach ($x in $all) {
            if (($ids -contains [int]$x.ParentProcessId) -and ($ids -notcontains [int]$x.ProcessId)) { $ids += [int]$x.ProcessId; $grew = $true }
        }
    }
    return $ids
}

$before = @(Get-ChildItem $logs -Filter "*_Studio_*_last.log" | ForEach-Object { $_.FullName })
$already = @(Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
$start = Get-Date
$p = Start-Process -FilePath $studio -ArgumentList "-task EditPlace -placeId $placeId -universeId $universeId" -WindowStyle Minimized -PassThru
"started Studio $($p.Id) (leaving alone: $($already -join ', '))"

$log = $null
$seen = 0
$done = $false
while (((Get-Date) - $start).TotalSeconds -lt $Seconds) {
    Start-Sleep -Milliseconds 700
    if ($p.HasExited) { "that Studio exited by itself ($($p.ExitCode))"; break }
    $family = @(Family $p.Id)
    foreach ($id in $family) { [DGPass.Win]::MinimiseAll([uint32]$id) }
    try { [void][DGEHAudio.Mixer]::Mute([int[]]$family) } catch {}
    if (-not $log) {
        $log = Get-ChildItem $logs -Filter "*_Studio_*_last.log" | Where-Object { $before -notcontains $_.FullName } |
            Sort-Object LastWriteTime | Select-Object -Last 1 -ExpandProperty FullName
        if ($log) { "log: $(Split-Path $log -Leaf)" }
    }
    if ($log) {
        $stream = [System.IO.File]::Open($log, 'Open', 'Read', 'ReadWrite,Delete')
        $reader = New-Object System.IO.StreamReader($stream)
        $text = $reader.ReadToEnd(); $reader.Close(); $stream.Close()
        $lines = @($text -split "`n" | Where-Object { $_ -match "\[DGPASS\]" })
        for ($i = $seen; $i -lt $lines.Count; $i++) {
            ($lines[$i] -replace "^.*\[FLog::[A-Za-z]+\]\s*", "").Trim()
        }
        $seen = $lines.Count
        if ($text -match [regex]::Escape($Until)) { $done = $true; break }
    }
}
if (-not $done) { "no '$Until' after $Seconds s" }

# Only the Studio started here.
if (-not $p.HasExited) {
    $family = @(Family $p.Id)
    [void]$p.CloseMainWindow()
    if (-not $p.WaitForExit(8000)) { foreach ($id in $family) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }; "stopped $($family -join ', ')" } else { "closed $($p.Id)" }
}
"still running: " + ((Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | ForEach-Object { "$($_.Id) '$($_.MainWindowTitle)'" }) -join "; ")
