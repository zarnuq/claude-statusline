# Installs the custom Claude Code statusline on Windows using native PowerShell.
# Usage: powershell -ExecutionPolicy Bypass -File install.ps1
#    or: irm https://raw.githubusercontent.com/zarnuq/claude-statusline/master/install.ps1 | iex

$ErrorActionPreference = "Stop"

$ScriptDir = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { "" }
$RawUrl = "https://raw.githubusercontent.com/zarnuq/claude-statusline/master"
$ClaudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME ".claude" }
$StatuslineDest = Join-Path $ClaudeDir "statusline-command.ps1"
$SettingsPath = Join-Path $ClaudeDir "settings.json"

function Install-File([string]$name) {
    $dest = Join-Path $ClaudeDir $name
    if ($ScriptDir -and (Test-Path (Join-Path $ScriptDir $name))) { Copy-Item -Path (Join-Path $ScriptDir $name) -Destination $dest -Force }
    else {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing -Uri "$RawUrl/$name" -OutFile $dest
    }
}

Write-Host "Installing Claude Code statusline into $ClaudeDir ..."
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
Install-File "statusline-command.ps1"

$ShellExe = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { "pwsh.exe" } else { "powershell.exe" }
$Command = "`"$ShellExe`" -NoProfile -ExecutionPolicy Bypass -File `"$StatuslineDest`""

if (Test-Path $SettingsPath) {
    $Json = Get-Content $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $Json = [PSCustomObject]@{}
}

$StatusLineObj = [PSCustomObject]@{ type = "command"; command = $Command }
if ($Json.PSObject.Properties.Name -contains "statusLine") {
    $Json.statusLine = $StatusLineObj
} else {
    $Json | Add-Member -NotePropertyName "statusLine" -NotePropertyValue $StatusLineObj -Force
}
$JsonText = $Json | ConvertTo-Json -Depth 100
$FullSettingsPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SettingsPath)
[IO.File]::WriteAllText($FullSettingsPath, $JsonText, (New-Object Text.UTF8Encoding $false))

Write-Host "Done. Statusline installed at $StatuslineDest"
Write-Host "settings.json updated at $SettingsPath (other keys preserved)."
Write-Host "Note: the branch segment needs git.exe on PATH; everything else has no external dependency."
Write-Host "Restart Claude Code (or start a new session) to see it."
