# Whole-game audit play test (session 3e64b245): builds the throwaway harness place from the audit worktree,
# installs the temporary plugin, starts a second Studio on that place (minimised, then shown at the bottom of
# the z-order without being activated), waits for the probes, prints the [EHARNESS] lines, then stops only that
# Studio and removes the plugin. Never opens the owner's place.
# -Corner (session 66468828, the owner's yes once Roblox is closed): a small window in the screen's bottom-right
# corner, always on top but never activated, so the play client draws frames; the display is kept on meanwhile.
# -Min (2026-10-17, the owner asked: "minimize the window of the dummy studio playtest so it doesnt cover half my
# screen"): every harness Studio window stays minimised the whole run (re-minimised if Studio restores itself).
# -Off (2026-10-17): the harness Studio drawn at full rate but parked beyond the left edge of every screen (so it
# covers nothing), at the bottom of the z-order, never activated: minimised Studio draws 15 frames a second and
# no 3D, too few to measure motion by.
param([switch]$Top, [switch]$Corner, [switch]$Min, [switch]$Off, [switch]$Sliver, [int]$Minutes = 16, [string]$Probe = "Probe", [string[]]$Attr = @(), [string]$CornerSize = "640x420")
$ErrorActionPreference = "Continue"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$scratch = Split-Path -Parent $here
$py = "C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe"
$rojo = Join-Path $scratch "tools\rojo.exe"
$studio = (Get-ChildItem (Join-Path $env:LOCALAPPDATA "Roblox\Versions") -Recurse -Filter "RobloxStudioBeta.exe" |
    Sort-Object LastWriteTime | Select-Object -Last 1).FullName
$place = Join-Path $here "dg_emote_harness.rbxl"
$plugins = Join-Path $env:LOCALAPPDATA "Roblox\Plugins"
$plugin = Join-Path $plugins "DGEmoteHarness.lua"

& $py -I (Join-Path $here "make_project.py") $Probe @Attr
& $rojo build (Join-Path $here "emote.project.json") -o $place
if ($LASTEXITCODE -ne 0) { "rojo build failed"; exit 1 }
New-Item -ItemType Directory -Force $plugins | Out-Null
Copy-Item (Join-Path $here "DGHarness.lua") $plugin -Force

Add-Type -Namespace DGEH -Name Win -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr h, int cmd);
[DllImport("user32.dll")] public static extern bool SetWindowPos(System.IntPtr h, System.IntPtr after, int x, int y, int w, int hgt, uint flags);
[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint f);
'@
Add-Type -AssemblyName System.Windows.Forms
$area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$cw, $ch = [int]($CornerSize.Split("x")[0]), [int]($CornerSize.Split("x")[1])
$cx, $cy = ($area.Right - $cw), ($area.Bottom - $ch)

function PlaceCorner($h) {
    # HWND_TOPMOST, SWP_NOACTIVATE | SWP_SHOWWINDOW
    [DGEH.Win]::SetWindowPos($h, [System.IntPtr](-1), $cx, $cy, $cw, $ch, 0x50) | Out-Null
}

# Beyond the left edge of the whole desktop (all screens), at the bottom of the z-order, not activated. With
# -Sliver instead: all but a 2-pixel corner of it beyond the primary screen's bottom-right corner, on top (Windows
# throttles a window nobody can see to 15 frames a second after a while; a sliver still counts as seen).
$virtual = [System.Windows.Forms.SystemInformation]::VirtualScreen
$ow, $oh = $cw, $ch
$ox, $oy = ($virtual.Left - $ow - 200), $virtual.Top
if ($Sliver) { $ox, $oy = ($area.Right - 2), ($area.Bottom - 2) }
function PlaceOff($h) {
    # HWND_BOTTOM (HWND_TOPMOST for the sliver), SWP_NOACTIVATE | SWP_SHOWWINDOW
    [DGEH.Win]::ShowWindow($h, 4) | Out-Null
    $after = if ($Sliver) { [System.IntPtr](-1) } else { [System.IntPtr]1 }
    [DGEH.Win]::SetWindowPos($h, $after, $ox, $oy, $ow, $oh, 0x50) | Out-Null
}
function KeepOff {
    $mine = @(HarnessStudios | ForEach-Object { $_.ProcessId })
    $ids = $mine + @(Get-CimInstance Win32_Process -Filter "Name='RobloxStudioBeta.exe'" |
        Where-Object { $mine -contains $_.ParentProcessId } | ForEach-Object { $_.ProcessId })
    foreach ($id in ($ids | Select-Object -Unique)) {
        $h = (Get-Process -Id $id -ErrorAction SilentlyContinue).MainWindowHandle
        if ($h -and $h -ne [System.IntPtr]::Zero) { PlaceOff $h }
    }
}
if ($Corner -or $Off) { [DGEH.Win]::SetThreadExecutionState([uint32]2147483651) | Out-Null }

function HarnessStudios {
    Get-CimInstance Win32_Process -Filter "Name='RobloxStudioBeta.exe'" |
        Where-Object { $_.CommandLine -like "*dg_emote_harness*" }
}

# Minimises (without activating) the harness Studio's window and those of any Studio it started (a play test's
# own windows); never a Studio the owner opened.
function KeepMinimised {
    $mine = @(HarnessStudios | ForEach-Object { $_.ProcessId })
    $ids = $mine + @(Get-CimInstance Win32_Process -Filter "Name='RobloxStudioBeta.exe'" |
        Where-Object { $mine -contains $_.ParentProcessId } | ForEach-Object { $_.ProcessId })
    foreach ($id in ($ids | Select-Object -Unique)) {
        $h = (Get-Process -Id $id -ErrorAction SilentlyContinue).MainWindowHandle
        # SW_SHOWMINNOACTIVE
        if ($h -and $h -ne [System.IntPtr]::Zero) { [DGEH.Win]::ShowWindow($h, 7) | Out-Null }
    }
}


# Windows' audio sessions: the harness's own Studio processes are muted (the owner, 2026-10-25: "please mute studio
# when you run tests"); nothing else is touched. Sessions appear only once a process plays a sound, so it runs again
# every few seconds.
Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
namespace DGEHAudio {
  [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMMDeviceEnumerator {
    [PreserveSig] int EnumAudioEndpoints(int dataFlow, int stateMask, out IntPtr devices);
    [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
  }
  [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMMDevice {
    [PreserveSig] int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object iface);
  }
  [ComImport, Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IAudioSessionManager2 {
    [PreserveSig] int GetAudioSessionControl(IntPtr sessionGuid, int flags, out IntPtr control);
    [PreserveSig] int GetSimpleAudioVolume(IntPtr sessionGuid, int flags, out IntPtr volume);
    [PreserveSig] int GetSessionEnumerator(out IAudioSessionEnumerator sessions);
  }
  [ComImport, Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IAudioSessionEnumerator {
    [PreserveSig] int GetCount(out int count);
    [PreserveSig] int GetSession(int index, out IAudioSessionControl2 session);
  }
  [ComImport, Guid("bfb7ff88-7239-4fc9-8fa2-07c950be9c6d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IAudioSessionControl2 {
    [PreserveSig] int GetState(out int state);
    [PreserveSig] int GetDisplayName(out IntPtr name);
    [PreserveSig] int SetDisplayName(IntPtr name, IntPtr context);
    [PreserveSig] int GetIconPath(out IntPtr path);
    [PreserveSig] int SetIconPath(IntPtr path, IntPtr context);
    [PreserveSig] int GetGroupingParam(out Guid grouping);
    [PreserveSig] int SetGroupingParam(ref Guid grouping, IntPtr context);
    [PreserveSig] int RegisterAudioSessionNotification(IntPtr client);
    [PreserveSig] int UnregisterAudioSessionNotification(IntPtr client);
    [PreserveSig] int GetSessionIdentifier(out IntPtr id);
    [PreserveSig] int GetSessionInstanceIdentifier(out IntPtr id);
    [PreserveSig] int GetProcessId(out int pid);
  }
  [ComImport, Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface ISimpleAudioVolume {
    [PreserveSig] int SetMasterVolume(float level, ref Guid context);
    [PreserveSig] int GetMasterVolume(out float level);
    [PreserveSig] int SetMute(bool mute, ref Guid context);
    [PreserveSig] int GetMute(out bool mute);
  }
  [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
  class MMDeviceEnumerator {}
  public static class Mixer {
    // Mutes every audio session (on the default output, for each role) whose process is one of `pids`; returns how
    // many it muted.
    public static int Mute(int[] pids) {
      var wanted = new HashSet<int>(pids);
      int muted = 0;
      var enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumerator());
      foreach (int role in new int[] { 0, 1, 2 }) {
        IMMDevice device;
        if (enumerator.GetDefaultAudioEndpoint(0, role, out device) != 0 || device == null) continue;
        Guid iid = new Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F");
        object o;
        if (device.Activate(ref iid, 23, IntPtr.Zero, out o) != 0) continue;
        var manager = (IAudioSessionManager2)o;
        IAudioSessionEnumerator sessions;
        if (manager.GetSessionEnumerator(out sessions) != 0) continue;
        int count;
        sessions.GetCount(out count);
        for (int i = 0; i < count; i++) {
          IAudioSessionControl2 control;
          if (sessions.GetSession(i, out control) != 0 || control == null) continue;
          int pid;
          control.GetProcessId(out pid);
          if (!wanted.Contains(pid)) continue;
          var volume = control as ISimpleAudioVolume;
          if (volume == null) continue;
          Guid none = Guid.Empty;
          bool already;
          volume.GetMute(out already);
          if (!already) { volume.SetMute(true, ref none); muted++; }
        }
      }
      return muted;
    }
  }
}
'@ -ErrorAction SilentlyContinue

function MuteHarness {
    $mine = @(HarnessStudios | ForEach-Object { [int]$_.ProcessId })
    $ids = $mine + @(Get-CimInstance Win32_Process -Filter "Name='RobloxStudioBeta.exe'" |
        Where-Object { $mine -contains $_.ParentProcessId } | ForEach-Object { [int]$_.ProcessId })
    if ($ids.Count -gt 0) {
        try { $n = [DGEHAudio.Mixer]::Mute([int[]]($ids | Select-Object -Unique)); if ($n -gt 0) { "muted $n audio session(s)" } } catch { "mute failed: $_" }
    }
}
$start = Get-Date
"studio: $studio"
$p = Start-Process -FilePath $studio -ArgumentList "`"$place`"" -WindowStyle Minimized -PassThru
"started Studio $($p.Id) at $start"

$shown = $false
for ($i = 0; $i -lt 40 -and -not $shown; $i++) {
    Start-Sleep -Seconds 3
    MuteHarness
    foreach ($proc in HarnessStudios) {
        $h = (Get-Process -Id $proc.ProcessId -ErrorAction SilentlyContinue).MainWindowHandle
        if ($h -and $h -ne [System.IntPtr]::Zero) {
            if ($Min) {
                KeepMinimised
                $shown = $true
                "kept minimised: process $($proc.ProcessId)"
                continue
            }
            if ($Off) {
                KeepOff
                $shown = $true
                "parked off-screen (${ow}x${oh} at $ox,$oy): process $($proc.ProcessId)"
                continue
            }
            [DGEH.Win]::ShowWindow($h, 4) | Out-Null
            if ($Corner) {
                PlaceCorner $h
                $shown = $true
                "shown in the corner (${cw}x${ch} at $cx,$cy), on top, not activated: process $($proc.ProcessId)"
                continue
            }
            $after = if ($Top) { [System.IntPtr]0 } else { [System.IntPtr]1 }
            [DGEH.Win]::SetWindowPos($h, $after, 0, 0, 1920, 1080, 0x50) | Out-Null
            $shown = $true
            "shown $(if ($Top) { 'on top, not activated' } else { 'at the bottom' }): process $($proc.ProcessId)"
        }
    }
}

$deadline = (Get-Date).AddMinutes($Minutes)
$log = $null
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 2
    MuteHarness
    if ($Min) { KeepMinimised }
    if ($Off) { KeepOff }
    if ($Corner) {
        # (Kept there: Studio may resize itself when the place loads or the test starts, or relaunch.)
        foreach ($proc in HarnessStudios) {
            $h = (Get-Process -Id $proc.ProcessId -ErrorAction SilentlyContinue).MainWindowHandle
            if ($h -and $h -ne [System.IntPtr]::Zero) { PlaceCorner $h }
        }
    }
    $candidates = Get-ChildItem (Join-Path $env:LOCALAPPDATA "Roblox\logs") -Filter "*Studio*_last.log" |
        Where-Object { $_.LastWriteTimeUtc -gt $start.ToUniversalTime() }
    foreach ($c in $candidates) {
        if (Select-String -Path $c.FullName -Pattern "\[EHARNESS\] start dg_emote_harness" -Quiet) { $log = $c.FullName }
    }
    if ($log -and (Select-String -Path $log -Pattern "\[EHARNESS\] DONE" -Quiet)) { break }
    if (-not (HarnessStudios)) { "the harness Studio is gone"; break }
}
"log: $log"
if ($log) {
    Copy-Item $log (Join-Path $here "last_run.log") -Force
    Select-String -Path $log -Pattern "\[EHARNESS\]" | ForEach-Object { $_.Line -replace "^.*?\[EHARNESS\]", "[EHARNESS]" }
}

foreach ($proc in HarnessStudios) { Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue; "stopped $($proc.ProcessId)" }
Remove-Item $plugin -Force -ErrorAction SilentlyContinue
"plugin removed: $(-not (Test-Path $plugin))"
if ($Corner -or $Off) { [DGEH.Win]::SetThreadExecutionState([uint32]2147483648) | Out-Null }
"pictures since the start:"
# (copied at once into the harness's captures folder: Roblox clears its own temp folder when it restarts)
$keep = Join-Path $here "captures"
New-Item -ItemType Directory -Force $keep | Out-Null
Get-ChildItem (Join-Path $env:LOCALAPPDATA "Roblox\tmp-capture-storage") -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTimeUtc -gt $start.ToUniversalTime() } | Sort-Object LastWriteTime |
    ForEach-Object {
        $copy = Join-Path $keep $_.Name
        Copy-Item $_.FullName $copy -Force
        "$($_.LastWriteTime.ToString('HH:mm:ss')) $($_.Length) $copy"
    }
"finished $(Get-Date)"
