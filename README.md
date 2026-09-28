# Usagebar (clone)

A native SwiftUI macOS menu bar app that shows your Claude Code 5-hour and
weekly usage limits at a glance — a from-scratch recreation of
[usagebar.com](https://usagebar.com)'s core loop.

## How it works

1. Reads the OAuth credentials Claude Code (the CLI) already stores in your
   macOS login Keychain, under the generic-password service
   `Claude Code-credentials` (same item `claude` creates when you log in).
2. Calls Anthropic's usage endpoint directly with that token:
   `GET https://api.anthropic.com/api/oauth/usage`
   (headers: `Authorization: Bearer <token>`, `anthropic-version: 2023-06-01`).
3. Shows the `five_hour` and `seven_day` utilization percentages and reset
   timers in a menu bar dropdown, polling every 60 seconds.

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
Gatekeeper and Keychain prompts behave normally.

The first launch will trigger a standard macOS Keychain access prompt
("Usagebar wants to use your confidential information stored in
'Claude Code-credentials'..."). Choose **Always Allow**.

## What's implemented (core loop)

- Menu bar badge showing live 5-hour usage %
- Dropdown panel with 5-hour and weekly progress bars + reset countdowns
- Plan badge (Pro/Max, from your Claude Code login)
- Manual refresh + 60s auto-refresh
- Graceful error state if Claude Code isn't installed/logged in, or the
  login has expired

## Not implemented yet

- Tiered notifications (50/75/90%)
- Context-window tracking
- Today's message/token stats
- Launch-at-login, settings UI, app icon
