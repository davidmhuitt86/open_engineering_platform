<#
.SYNOPSIS
    Reusable automated Flutter hot-reload driver for OEP Studio.

.DESCRIPTION
    Development tool only -- not part of the OEP Studio application.
    Solves a concrete gap in this environment: background processes can
    be started and their stdout read, but nothing can send keystrokes
    (the interactive `r`/`R` for hot reload/restart) into a running
    `flutter run` session's stdin. This script starts `flutter run
    --debug -d windows` in the background, captures its VM Service URI
    from stdout, and drives genuine hot reload afterward via the Dart VM
    Service JSON-RPC protocol (`hot_reload_client.dart`, pure
    `dart:io` -- no extra packages), instead of merely restarting the
    process.

.PARAMETER Action
    start   - launch flutter run --debug -d windows and capture its VM
              Service URI.
    reload  - perform a genuine hot reload (reloadSources +
              ext.flutter.reassemble) against the running session.
    stop    - terminate the specific flutter run process tree this
              script started (never any other Flutter/Dart process).
    status  - report whether a session is running and reachable.

.EXAMPLE
    .\tools\flutter_hot_reload.ps1 start
    .\tools\flutter_hot_reload.ps1 reload
    .\tools\flutter_hot_reload.ps1 stop
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('start', 'reload', 'stop', 'status')]
    [string]$Action
)

$ErrorActionPreference = 'Stop'

$ProjectDir = Split-Path -Parent $PSScriptRoot
$StateDir = Join-Path $ProjectDir '.dev_tools'
$StateFile = Join-Path $StateDir 'hot_reload_session.json'
$RunLog = Join-Path $StateDir 'flutter_run.log'
$RunErrLog = Join-Path $StateDir 'flutter_run.err.log'
$ClientScript = Join-Path $PSScriptRoot 'hot_reload_client.dart'

function Get-SessionState {
    if (Test-Path $StateFile) {
        try { return Get-Content $StateFile -Raw | ConvertFrom-Json } catch { return $null }
    }
    return $null
}

function Test-ProcessAlive([int]$ProcessId) {
    return $null -ne (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)
}

function Write-Status([string]$Message) {
    Write-Host $Message
}

switch ($Action) {
    'start' {
        $existing = Get-SessionState
        if ($existing -and (Test-ProcessAlive $existing.pid)) {
            Write-Status "An OEP Studio Flutter debug session is already running (PID $($existing.pid)). Use 'reload' to hot-reload it, or 'stop' first."
            exit 1
        }
        if ($existing) {
            # Stale state file (process no longer alive) -- clear it before starting fresh.
            Remove-Item $StateFile -Force -ErrorAction SilentlyContinue
        }

        New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
        Remove-Item $RunLog, $RunErrLog -Force -ErrorAction SilentlyContinue

        $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
        if (-not $flutterCmd) {
            Write-Status "FAILED: 'flutter' was not found on PATH."
            exit 1
        }

        $proc = Start-Process -FilePath $flutterCmd.Source `
            -ArgumentList 'run', '--debug', '-d', 'windows' `
            -WorkingDirectory $ProjectDir `
            -NoNewWindow -PassThru `
            -RedirectStandardOutput $RunLog `
            -RedirectStandardError $RunErrLog

        Write-Status "Starting flutter run --debug -d windows (PID $($proc.Id)) -- waiting for VM Service URI..."

        $vmServiceHttpUri = $null
        $deadline = (Get-Date).AddSeconds(180)
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 2
            if (Test-Path $RunLog) {
                $content = Get-Content $RunLog -Raw -ErrorAction SilentlyContinue
                if ($content -match 'A Dart VM Service[^\r\n]* is available at: (http://\S+)') {
                    $vmServiceHttpUri = $matches[1]
                    break
                }
            }
            if (-not (Test-ProcessAlive $proc.Id)) {
                Write-Status "FAILED: flutter run exited before a VM Service URI appeared. See $RunLog / $RunErrLog"
                exit 1
            }
        }

        if (-not $vmServiceHttpUri) {
            Write-Status "FAILED: timed out waiting for the VM Service URI. See $RunLog"
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            exit 1
        }

        # http://127.0.0.1:PORT/TOKEN=/  ->  ws://127.0.0.1:PORT/TOKEN=/ws
        $wsUri = $vmServiceHttpUri -replace '^http://', 'ws://'
        if (-not $wsUri.EndsWith('/')) { $wsUri += '/' }
        $wsUri += 'ws'

        $state = [ordered]@{
            pid              = $proc.Id
            vmServiceHttpUri = $vmServiceHttpUri
            vmServiceWsUri   = $wsUri
            startedAt        = (Get-Date).ToString('o')
        }
        ($state | ConvertTo-Json) | Set-Content -Path $StateFile -Encoding utf8

        Write-Status "OEP Studio Flutter debug session started"
        Write-Status "VM Service detected: $vmServiceHttpUri"
        Write-Status "PID: $($proc.Id)"
    }

    'reload' {
        $state = Get-SessionState
        if (-not $state) {
            Write-Status "No OEP Studio Flutter debug session is currently running."
            exit 1
        }
        if (-not (Test-ProcessAlive $state.pid)) {
            Write-Status "No OEP Studio Flutter debug session is currently running. (stale state file -- process $($state.pid) is not alive; removing it)"
            Remove-Item $StateFile -Force -ErrorAction SilentlyContinue
            exit 1
        }

        $pidBefore = $state.pid

        # Drives `flutter attach --machine`, the same JSON-RPC-over-
        # stdio protocol `flutter run`'s own interactive `r` keypress
        # uses internally -- this is Flutter's own incremental-compiler
        # orchestration (existing tooling, per the task's own
        # preference), not a raw unassisted VM Service `reloadSources`
        # call. A raw `reloadSources` call was tried first and
        # consistently failed with "Error while starting Kernel isolate
        # task" on this Windows desktop debug target -- that path needs
        # the compiled-kernel diff `flutter_tool`'s incremental compiler
        # normally supplies, which a bare VM Service RPC does not
        # provide. `flutter attach` supplies it correctly because it *is*
        # that same tool. See `hot_reload_client.dart` for the abandoned
        # raw-VM-Service attempt, kept for reference/report purposes.
        $flutterCmd = (Get-Command flutter -ErrorAction Stop).Source
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $flutterCmd
        $psi.Arguments = "attach --machine --debug-url `"$($state.vmServiceHttpUri)`" -d windows"
        $psi.WorkingDirectory = $ProjectDir
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $attach = New-Object System.Diagnostics.Process
        $attach.StartInfo = $psi
        [void]$attach.Start()

        $appId = $null
        $restartResult = $null
        $sawResponse = $false
        $deadline = (Get-Date).AddSeconds(45)
        $sentRestart = $false

        try {
            while ((Get-Date) -lt $deadline -and -not $sawResponse) {
                if ($attach.StandardOutput.EndOfStream) { Start-Sleep -Milliseconds 200; continue }
                $line = $attach.StandardOutput.ReadLine()
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                if ($line -notmatch '^\[') { continue }  # machine-mode frames are JSON arrays
                try { $events = $line | ConvertFrom-Json } catch { continue }
                foreach ($evt in $events) {
                    if ($evt.event -eq 'app.started' -and -not $sentRestart) {
                        $appId = $evt.params.appId
                        $cmd = @{ id = 1; method = 'app.restart'; params = @{ appId = $appId; fullRestart = $false } }
                        $attach.StandardInput.WriteLine(( @($cmd) | ConvertTo-Json -Compress -Depth 5 ))
                        $attach.StandardInput.Flush()
                        $sentRestart = $true
                    }
                    if ($null -ne $evt.id -and $evt.id -eq 1) {
                        $restartResult = $evt
                        $sawResponse = $true
                    }
                }
            }
        } finally {
            # This `attach` process is a temporary observer of the
            # already-running app -- detaching/killing it does not touch
            # the target OEP Studio process (PID $pidBefore).
            if (-not $attach.HasExited) {
                try { $attach.StandardInput.WriteLine('[{"id":2,"method":"app.detach","params":{}}]'); $attach.StandardInput.Flush() } catch {}
                Start-Sleep -Milliseconds 300
                if (-not $attach.HasExited) { $attach.Kill() }
            }
        }

        $pidAfter = if (Test-ProcessAlive $pidBefore) { $pidBefore } else { $null }

        if (-not $sawResponse) {
            Write-Status "HOT RELOAD: FAILED (no app.restart response from 'flutter attach --machine' within timeout) (PID before=$pidBefore, PID after=$pidAfter)"
            exit 1
        }
        if ($restartResult.error) {
            Write-Status "HOT RELOAD: FAILED ($($restartResult.error)) (PID before=$pidBefore, PID after=$pidAfter)"
            exit 1
        }

        Write-Status "HOT RELOAD: SUCCESS (appId=$appId, PID before=$pidBefore, PID after=$pidAfter)"
        exit 0
    }

    'stop' {
        $state = Get-SessionState
        if (-not $state) {
            Write-Status "No OEP Studio Flutter debug session is currently running."
            exit 0
        }
        if (Test-ProcessAlive $state.pid) {
            # taskkill /T kills the process tree -- flutter.bat/flutter run
            # spawns child dart.exe/oep_studio.exe processes that
            # Stop-Process alone would leave orphaned. Scoped to exactly
            # this PID's tree, never any other Flutter/Dart process.
            & taskkill /PID $state.pid /T /F | Out-Null
            Write-Status "Stopped Flutter debug session (PID $($state.pid)) and its process tree."
        } else {
            Write-Status "Process $($state.pid) was already gone."
        }
        Remove-Item $StateFile -Force -ErrorAction SilentlyContinue
    }

    'status' {
        $state = Get-SessionState
        if (-not $state) {
            Write-Status "No OEP Studio Flutter debug session is currently running."
            exit 0
        }
        $alive = Test-ProcessAlive $state.pid
        Write-Status "PID $($state.pid) alive=$alive startedAt=$($state.startedAt) vmService=$($state.vmServiceHttpUri)"
        if (-not $alive) { exit 1 }
    }
}
