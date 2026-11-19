# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A custom two-line truecolor statusline for Claude Code, implemented as two independent,
functionally-identical scripts — one per platform family — plus their installers. There is no
build system, package manifest, or test suite; this is a pair of standalone shell/PowerShell
scripts consumed directly by Claude Code's `statusLine` settings hook.

- `statusline-command.sh` — Linux/macOS/WSL implementation (bash + `jq`). Single `jq` call for
  all JSON extraction; pure bash arithmetic for color interpolation (no `awk`).
- `statusline-command.ps1` — Windows implementation, a native PowerShell port with **no
  dependency on bash, `jq`, or Git for Windows** (only `git.exe` on PATH, and only for the
  branch segment).
- `install.sh` / `install.ps1` — copy the matching script to `~/.claude/` (or
  `$CLAUDE_CONFIG_DIR`) and merge a `statusLine` key into `~/.claude/settings.json` without
  touching other settings.

## Critical constraint: the two scripts must stay in sync

**`statusline-command.sh` and `statusline-command.ps1` are two hand-maintained ports of the same
logic.** There is no shared source of truth and no automated check that they match. Whenever you
change one (new segment, color tweak, formatting change, bug fix), make the equivalent change in
the other, translating idioms as needed (e.g. `jq -r '.foo.bar // empty'` ↔
`$data.foo.bar`, ANSI escapes via `\033[...m` in bash vs `$ESC[...m` in PowerShell). Verify both
before considering a change complete.

The README's preview images (`docs/*.svg`) are hand-written SVG mockups, not generated; update them
when a change alters the rendered look.

## How data flows

Claude Code invokes the configured `statusLine` command once per render, piping a JSON payload on
stdin (session/model/cost/context/rate-limit/workspace state) and expecting two lines of text
(with ANSI truecolor escapes) on stdout. Both scripts follow the same shape:

1. Read all of stdin as one JSON blob (`input=$(cat)` in bash; `[Console]::In.ReadToEnd()` +
   `ConvertFrom-Json` in PowerShell).
2. Extract all fields in one pass (bash uses a single `jq` call with `read` assignments;
   PowerShell accesses `$data` properties directly).
3. Build segments inline — model+effort, context (emoji + circle glyph + colored percentage),
   rate limits (circle glyph + percentage + reset time/countdown), cost, velocity, cwd,
   branch/worktree, output style — each conditionally rendered only if its underlying JSON
   field is present.
4. Print two lines joined with dim-gray ` | ` separators.

**Line 1**: model(effort) | context | 5h rate limit | 7d rate limit | cost | velocity
**Line 2**: cwd | branch/worktree | output style

Key details worth knowing before editing:

- **Context indicator**: a colored circle glyph (`○ ◔ ◑ ◕ ●`) + usage emoji (`🟢 ⚡ 🔥 🚨`)
  driven by `context_window.used_percentage`. The circle and percentage text are both colored
  via `color_rgb`/`Color-At` linear interpolation: green(25,180,95) → yellow(220,200,0) →
  red(220,40,20). Bash uses integer arithmetic (truncation); PowerShell uses `[math]::Truncate`
  to match.
- **Rate limits**: `rate_limits.five_hour` and `rate_limits.seven_day`, each rendered with the
  same 5-stage circle glyph. `five_hour` shows a local-time clock (`resets_at` epoch → local
  `h:mm a`; bash tries GNU `date -d` first, falling back to BSD `date -r` for macOS; PowerShell
  uses `[DateTimeOffset]::FromUnixTimeSeconds(...)`). `seven_day` shows a countdown duration
  like `(9d2h)` via bash arithmetic / .NET math, not a clock time.
- **Worktree awareness**: when `workspace.git_worktree` is present (a Claude Code
  `EnterWorktree`-isolated session), line 2 shows the worktree name and its
  `worktree.original_branch` instead of the plain current branch. The plain-branch segment
  (`git rev-parse --abbrev-ref HEAD` against `workspace.current_dir`) is only computed/shown when
  *not* in such a session.
- **Numeric formatting/rounding parity**: PowerShell's default numeric formatting traps are easy
  to reach for and *look* equivalent to the bash side but aren't. Use `F`-format specifiers
  (`"{0:F2}"`), never `N`-format (`"{0:N2}"`) — `N` inserts thousands separators (`$1,234.56`)
  that bash's `printf "%.2f"` never produces. RGB channels in `Color-At` must use
  `[math]::Truncate`, not `Round` — the bash `color_rgb` truncates via integer arithmetic.

## Testing changes

There's no automated test suite. To validate a change, pipe a representative JSON payload into
the script directly and inspect the rendered output, e.g.:

```sh
echo '{"model":{"display_name":"Claude"},"context_window":{"used_percentage":42},"cost":{"total_cost_usd":1.23,"total_lines_added":10,"total_lines_removed":2},"rate_limits":{"five_hour":{"used_percentage":30,"resets_at":1750000000}},"workspace":{"current_dir":"'"$PWD"'"}}' | bash statusline-command.sh
```

The bash script needs `jq` on PATH. For PowerShell, pipe equivalent JSON through both
`pwsh -File statusline-command.ps1` and `powershell.exe -File statusline-command.ps1`: the installer
falls back to Windows PowerShell 5.1 when PowerShell 7 isn't installed, so the PS scripts must work
in both. That's why they use `$ESC` (`[char]27`) instead of `` `e `` (7-only) and read/write raw
UTF-8 via `[Console]::OpenStandard*` (5.1 defaults to the OEM code page). After editing, re-run the relevant installer
(`./install.sh` or `install.ps1`) to redeploy the script to `~/.claude/` if you want to see it
live in a real Claude Code session — restart Claude Code (or start a new session) afterward, since
the statusline command is only re-read at session start.

## Editing colors/layout

Colors and segment order are hardcoded truecolor ANSI escapes (`\033[38;2;R;G;Bm` / RGB literals
near each segment) directly in the two scripts — there's no theme/config file. Change them in
place in both scripts per the sync requirement above.
