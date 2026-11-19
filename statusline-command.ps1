# Claude Code two-line truecolor statusline (PowerShell port)
# Line 1: model(effort) | mode | ctx | 5h | 7d | cost | velocity
# Line 2: cwd | branch/worktree

$inputJson = (New-Object IO.StreamReader([Console]::OpenStandardInput(), [Text.Encoding]::UTF8)).ReadToEnd()
$data = $inputJson | ConvertFrom-Json

$ESC = [char]27
$R = "$ESC[0m"
$PIPE = "$ESC[38;2;110;110;110m | $R"

function Color-At([double]$p) {
    if ($p -le 50) {
        $f = $p / 50.0
        @([math]::Truncate(25 + 195 * $f), [math]::Truncate(180 + 20 * $f), [math]::Truncate(95 - 95 * $f))
    } else {
        $f = ($p - 50) / 50.0
        @(220, [math]::Truncate(200 - 160 * $f), [math]::Truncate(20 * $f))
    }
}

function Shade-Glyph([double]$p) {
    if ($p -lt 25) { [char]0x2591 }      # ░
    elseif ($p -lt 50) { [char]0x2592 }  # ▒
    elseif ($p -lt 75) { [char]0x2593 }  # ▓
    else { [char]0x2588 }                # █
}

function Circle-Glyph([double]$p) {
    if ($p -lt 20) { [char]0x25CB }      # ○
    elseif ($p -lt 40) { [char]0x25D4 }  # ◔
    elseif ($p -lt 60) { [char]0x25D1 }  # ◑
    elseif ($p -lt 80) { [char]0x25D5 }  # ◕
    else { [char]0x25CF }                # ●
}

function Usage-Emoji([double]$p) {
    if ($p -lt 20) { "$([char]0xD83D)$([char]0xDFE2)" }      # 🟢
    elseif ($p -lt 70) { [char]0x26A1 }                       # ⚡
    elseif ($p -lt 90) { "$([char]0xD83D)$([char]0xDD25)" }   # 🔥
    else { "$([char]0xD83D)$([char]0xDEA8)" }                 # 🚨
}

# --- model + effort ---
$model = if ($data.model.display_name) { $data.model.display_name } else { "unknown" }
$effort = $data.effort.level
$L = "$ESC[1;38;2;217;119;87m$model$R"
if ($effort) { $L += " $ESC[38;2;217;119;87m($effort)$R" }

# --- mode ---
if ($data.output_style.name) { $L += "$PIPE$ESC[38;2;215;225;130m$($data.output_style.name)$R" }

# --- context ---
$usedPct = if ($data.context_window.used_percentage) { $data.context_window.used_percentage } else { 0 }
$rgb = Color-At $usedPct
$L += "$PIPE$(Usage-Emoji $usedPct) $ESC[1;38;2;$($rgb[0]);$($rgb[1]);$($rgb[2])m$(Shade-Glyph $usedPct) $("{0:F0}%" -f $usedPct)$R"

# --- rate limits ---
$C_RL = "$ESC[38;2;120;200;255m"
if ($null -ne $data.rate_limits.five_hour.used_percentage) {
    $p = $data.rate_limits.five_hour.used_percentage
    $resetStr = ""
    if ($data.rate_limits.five_hour.resets_at) {
        try { $resetStr = " (resets $([DateTimeOffset]::FromUnixTimeSeconds([int64]$data.rate_limits.five_hour.resets_at).ToLocalTime().ToString('h:mm tt')))" } catch { }
    }
    $L += "$PIPE${C_RL}5h: $(Circle-Glyph $p) $("{0:F0}%" -f $p)$resetStr$R"
}
if ($null -ne $data.rate_limits.seven_day.used_percentage) {
    $p = $data.rate_limits.seven_day.used_percentage
    $resetStr = ""
    if ($data.rate_limits.seven_day.resets_at) {
        try {
            $diff = [int64]$data.rate_limits.seven_day.resets_at - [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            if ($diff -lt 0) { $diff = 0 }
            $resetStr = " ($([math]::Floor($diff / 86400))d$([math]::Floor(($diff % 86400) / 3600))h)"
        } catch { }
    }
    $L += "$PIPE${C_RL}7d: $(Circle-Glyph $p) $("{0:F0}%" -f $p)$resetStr$R"
}

# --- cost + velocity ---
if ($null -ne $data.cost.total_cost_usd) {
    $L += "$PIPE$ESC[38;2;220;200;0m$('$' + ("{0:F2}" -f $data.cost.total_cost_usd))$R"
}
$added = $data.cost.total_lines_added; $removed = $data.cost.total_lines_removed
if (($null -ne $added) -or ($null -ne $removed)) {
    if ($null -eq $added) { $added = 0 }; if ($null -eq $removed) { $removed = 0 }
    $L += "$PIPE$ESC[38;2;25;180;95m+$added$R $ESC[38;2;220;40;20m-$removed$R"
}

# --- line 2: cwd | branch/worktree ---
$cwd = if ($data.workspace.current_dir) { $data.workspace.current_dir } else { (Get-Location).Path }
$L2 = "$ESC[38;2;150;200;255m$([char]0xD83D)$([char]0xDCC1) $cwd$R"

if ($data.workspace.git_worktree) {
    $L2 += "$PIPE$ESC[38;2;0;220;220m$([char]0xD83C)$([char]0xDF3F) $($data.workspace.git_worktree)$R"
    if ($data.worktree.original_branch) { $L2 += "$PIPE$ESC[38;2;220;180;0m$([char]0x2190) $($data.worktree.original_branch)$R" }
} else {
    try { $branch = git -C $cwd rev-parse --abbrev-ref HEAD 2>$null } catch { $branch = $null }
    if ($branch -and $branch -ne "HEAD") { $L2 += "$PIPE$ESC[38;2;120;200;120m$([char]0xD83C)$([char]0xDF3F) $branch$R" }
}

$bytes = (New-Object Text.UTF8Encoding $false).GetBytes("$L`n$L2`n")
$stdout = [Console]::OpenStandardOutput()
$stdout.Write($bytes, 0, $bytes.Length)
$stdout.Flush()
