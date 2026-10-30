[CmdletBinding()]
param([int]$Port = 9321)

$ErrorActionPreference = "Stop"
$logRoot = Join-Path $env:LOCALAPPDATA "Codex\locale-patch"
$logPath = Join-Path $logRoot "chatgpt-zh-cn-cdp.log"
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

function Write-PatchLog([string]$Message) {
    Add-Content -LiteralPath $logPath -Value "$(Get-Date -Format o) $Message" -Encoding UTF8
}

function Find-ChatGptExecutable {
    $package = Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending |
        Select-Object -First 1
    if ($null -ne $package) {
        $candidate = Join-Path $package.InstallLocation "app\ChatGPT.exe"
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }

    $candidate = Get-ChildItem -LiteralPath "C:\Program Files\WindowsApps" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "OpenAI.Codex_*" } |
        Sort-Object LastWriteTime -Descending |
        ForEach-Object { Join-Path $_.FullName "app\ChatGPT.exe" } |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1
    if ($null -ne $candidate) { return $candidate }

    throw "ChatGPT executable was not found."
}

function Find-ChatGptUserData {
    $candidates = @(
        (Join-Path $env:APPDATA "Codex\web\Codex"),
        (Join-Path $env:LOCALAPPDATA "Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Roaming\Codex\web\Codex")
    )
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        try {
            if (Test-Path -LiteralPath $candidate -ErrorAction Stop) { return $candidate }
        }
        catch {}
    }
    throw "ChatGPT user-data directory was not found."
}

function Send-WsText($Socket, [string]$Text) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    $segment = [ArraySegment[byte]]::new($bytes)
    $null = $Socket.SendAsync($segment, [Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
}

function Receive-WsText($Socket) {
    $buffer = New-Object byte[] 65536
    $stream = New-Object IO.MemoryStream
    do {
        $result = $Socket.ReceiveAsync([ArraySegment[byte]]::new($buffer), [Threading.CancellationToken]::None).GetAwaiter().GetResult()
        if ($result.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close) {
            throw "DevTools WebSocket closed."
        }
        $stream.Write($buffer, 0, $result.Count)
    } while (-not $result.EndOfMessage)
    return [Text.Encoding]::UTF8.GetString($stream.ToArray())
}

$existingTargets = $null
if (Get-Process -Name "ChatGPT" -ErrorAction SilentlyContinue) {
    try {
        $existingTargets = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json" -TimeoutSec 2
    }
    catch {}

    if ($null -ne $existingTargets) {
        Write-PatchLog "ChatGPT is already running with the language patch."
        exit 0
    }

    Write-PatchLog "Restarting an unpatched ChatGPT instance."
    Get-Process -Name "ChatGPT" -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue

    for ($wait = 0; $wait -lt 30; $wait++) {
        if ($null -eq (Get-Process -Name "ChatGPT" -ErrorAction SilentlyContinue)) {
            break
        }
        Start-Sleep -Milliseconds 250
    }

    if ($null -ne (Get-Process -Name "ChatGPT" -ErrorAction SilentlyContinue)) {
        throw "ChatGPT could not be stopped before applying the language patch."
    }
}

$exe = Find-ChatGptExecutable
$userData = Find-ChatGptUserData
Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue
Write-PatchLog "launcher started"
Write-PatchLog "executable=$exe"
Write-PatchLog "userData=$userData"

$arguments = @(
    "--user-data-dir=$userData",
    "--remote-debugging-address=127.0.0.1",
    "--remote-debugging-port=$Port",
    "--remote-allow-origins=*"
)
$process = Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory (Split-Path -Parent $exe) -PassThru
Write-PatchLog "startedPid=$($process.Id)"

$target = $null
for ($attempt = 0; $attempt -lt 90; $attempt++) {
    Start-Sleep -Milliseconds 500
    try {
        $target = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json" -TimeoutSec 2 |
            Where-Object {
                $_.type -eq "page" -and
                $_.url -like "app://*" -and
                -not [string]::IsNullOrWhiteSpace($_.webSocketDebuggerUrl)
            } |
            Select-Object -First 1
        if ($null -ne $target) { break }
    }
    catch {}
}

if ($null -eq $target) {
    Write-PatchLog "DevTools target not found."
    throw "ChatGPT started without a reachable DevTools target. See $logPath"
}

Write-PatchLog "target=$($target.url)"

$patchExpression = @'
(() => {
  const patchClient = (client) => {
    if (!client || typeof client.getLayer !== "function") return false;
    if (!client.__codexZhCnPatched) {
      const original = client.getLayer;
      client.getLayer = function(name, options) {
        const layer = original.call(this, name, options);
        if (String(name) !== "72216192" || !layer) return layer;
        return new Proxy(layer, {
          get(target, property, receiver) {
            if (property === "get") {
              return (key, fallback) => key === "enable_i18n" ? true : target.get(key, fallback);
            }
            return Reflect.get(target, property, receiver);
          }
        });
      };
      client.__codexZhCnPatched = true;
    }

    try {
      client.updateUserSync(client.getContext().user, { disableBackgroundCacheRefresh: true });
    } catch {}

    return true;
  };

  const root = window.__STATSIG__;
  let patched = false;
  if (root) {
    if (patchClient(root.firstInstance)) patched = true;
    if (root.instances) {
      for (const client of Object.values(root.instances)) {
        if (patchClient(client)) patched = true;
      }
    }
  }

  return patched;
})();
'@

$socket = [Net.WebSockets.ClientWebSocket]::new()
try {
    $socket.Options.Proxy = $null
    $socket.ConnectAsync([Uri]$target.webSocketDebuggerUrl, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    $nextId = 0
    function Invoke-Cdp([string]$Method, [hashtable]$Params = @{}) {
        $script:nextId += 1
        $requestId = $script:nextId
        $payload = @{ id = $requestId; method = $Method; params = $Params } |
            ConvertTo-Json -Depth 12 -Compress
        Send-WsText $script:socket $payload
        while ($true) {
            $message = Receive-WsText $script:socket | ConvertFrom-Json
            if ($message.id -eq $requestId) {
                if ($message.error) { throw "CDP error: $($message.error.message)" }
                return $message.result
            }
        }
    }

    [void](Invoke-Cdp "Runtime.enable")

    $ready = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        $state = Invoke-Cdp "Runtime.evaluate" @{
            expression = 'Boolean(window.__STATSIG__?.firstInstance || Object.keys(window.__STATSIG__?.instances || {}).length)'
            returnByValue = $true
        }
        if ($state.result.value -eq $true) {
            $ready = $true
            break
        }
        Start-Sleep -Milliseconds 500
    }

    if (-not $ready) {
        throw "Statsig client was not available in the renderer."
    }

    $patchResult = Invoke-Cdp "Runtime.evaluate" @{
        expression = $patchExpression
        returnByValue = $true
        awaitPromise = $true
    }
    Write-PatchLog "patchResult=$($patchResult.result.value)"

    Start-Sleep -Seconds 3
    $verification = Invoke-Cdp "Runtime.evaluate" @{
        expression = '(() => { const r=window.__STATSIG__; const c=r?.firstInstance||Object.values(r?.instances||{})[0]; return JSON.stringify({hasRoot:Boolean(r),hasClient:Boolean(c),enableI18n:c?.getLayer("72216192").get("enable_i18n",false)??null,lang:document.documentElement.lang}); })()'
        returnByValue = $true
        awaitPromise = $true
    }
    Write-PatchLog "verification=$($verification.result.value)"
}
catch {
    Write-PatchLog "patch failed: $($_.Exception.Message)"
    throw
}
finally {
    $socket.Dispose()
}

Write-Host "Runtime patch applied. Diagnostic log: $logPath"
