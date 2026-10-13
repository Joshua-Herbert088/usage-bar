# Usagebar (clone)

A native SwiftUI macOS menu bar app that shows your Claude Code 5-hour and
weekly usage limits at a glance — a from-scratch recreation of
[usagebar.com](https://usagebar.com)'s core loop.

## How it works

1. Reads the OAuth credentials Claude Code (the CLI) already stores in your
   macOS login Keychain, under the generic-password service
   `Claude Code-credentials` (same item `claude` creates when you log in).
   It reads the item via `/usr/bin/security`, the same tool the CLI uses to
   write it, so there are no Keychain password prompts — even after the CLI
   refreshes its token. The token is cached in memory and only re-read when
   it expires or the API rejects it.
2. Calls Anthropic's usage endpoint directly with that token:
   `GET https://api.anthropic.com/api/oauth/usage`
   (headers: `Authorization: Bearer <token>`, `anthropic-version: 2023-06-01`).
3. Shows the `five_hour` and `seven_day` utilization percentages and reset
   timers in a menu bar dropdown, polling every 90 seconds.

Credentials never leave your machine except to call Anthropic's API
directly — nothing is synced or stored elsewhere.

**Note:** `/api/oauth/usage` is not a published, stable Anthropic API. It was
found by inspecting strings in the `claude` CLI binary itself and may change
or stop working without notice.

## Requirements

- macOS 13+
- Swift 5.9+ (Xcode 15+ or the Swift toolchain)
- Claude Code installed and logged in at least once (`claude` in a terminal)

## Run it (development)

```bash
swift run
```

This runs the app directly; it'll show a generic icon in the Dock in
addition to the menu bar item, since there's no `.app` bundle yet.

## Build a real menu-bar-only app

```bash
./scripts/build_app.sh
open dist/Usagebar.app
```

This packages a release build into `dist/Usagebar.app` with `LSUIElement`
set, so it only lives in the menu bar (no Dock icon), and ad-hoc signs it so
Gatekeeper behaves normally.

If you ever do see a Keychain prompt mentioning `security`, choose
**Always Allow**.

## What's implemented

- Menu bar badge showing live 5-hour usage %
- Dropdown panel with 5-hour and weekly progress bars + reset countdowns
- Plan badge (Pro/Max, from your Claude Code login)
- Manual refresh + 90s auto-refresh, with backoff (respecting `Retry-After`)
  if the usage API responds 429
- Tiered notifications at 50/75/90% usage for each window, once per tier
  per reset cycle
- Launch at Login toggle (backed by `SMAppService`)
- Settings window (Launch at Login, a Usage Notifications toggle that
  actually gates alerts, app version) — opened via the dropdown's
  "Settings" button, since an LSUIElement app has no app menu
- Original app icon (`scripts/generate_icon.swift` → `.icns`)
- Guards against duplicate running instances doubling the poll rate
- Graceful error state if Claude Code isn't installed/logged in, or the
  login has expired

## Not implemented yet

- Context-window tracking
- Today's message/token stats
