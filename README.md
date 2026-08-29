# Codex Pace

Codex Pace compares the percentage of Codex's seven-day usage allowance remaining
with the percentage of the current seven-day window remaining.

> Codex Pace is an independent, unofficial community project. It is not
> affiliated with, endorsed by, or sponsored by OpenAI. Codex and OpenAI are
> trademarks of their respective owners.

Codex Pace opens as a regular Dock app with one main window. The menu bar also
shows `time / usage`, so `83.0% / 82%` means roughly 83% of the week and 82% of
usage remain. Click it for the exact values, pace, and reset time. When the pace
says **Slow down**, the **Stoppage time** row shows how long it would take to get
back on pace if weekly usage stopped increasing, followed by the date and time
when usage could resume. The **Projected runout** row beneath it shows when usage
would reach 0% if the average consumption rate since the window began continued
unchanged, as both a countdown and timestamp. At 0% usage remaining, the pace
label says **Stopped**.

The projected runout calculation uses the fixed **Next update** timestamp as its
observation point. Its timestamp therefore stays put during each two-minute
refresh interval while the countdown ticks, then recalculates after the next
usage reading.

Use the window button in the popover header to focus the main Codex Pace window.
The window shares the menu bar's live reading and refresh cycle. Closing it
leaves the app running; click its Dock icon to reopen the window.
Use the `2×` control in the main window to double the window and everything
inside it for viewing from farther away. The selection is remembered; use `1×`
to return to the standard size. Near a display's right edge, the window expands
left and keeps that right edge in place when returning to `1×`. The menu-bar
popover stays compact.

Use the calendar-and-clock button in the header when a one-off usage reset is
expected before the timestamp reported by Codex. Codex Pace shows the manual
value as **Reset by (est.)**, remembers it across launches, and automatically
returns to the Codex-reported timestamp after the estimate passes or Codex
reports that the weekly usage allowance has reset to 100% remaining.

Available banked resets appear in a collapsed section; click the section to show
their expiration countdowns and timestamps. When a known banked reset expires
before the natural reset, the main reset row becomes **Banked reset expires** and
counts down to that earlier deadline. Codex Pace preserves the server's
authoritative available count even when the server omits or caps detailed
expiration rows. A manual estimate also becomes the effective end of the
seven-day window, recalculating **Week left**, pace, and stoppage or time-ahead
values. A banked-reset expiration remains a deadline indicator only; it does not
change the pace calculation until a reset is actually applied.

## Build

```sh
./Scripts/build-app.sh
```

This creates:

- `dist/Codex Pace.app`
- `dist/bin/codex-pace`

Each app bundle is stamped with a build number derived from the Git commit count
and the exact source revision. The footer compares that revision with the public
repository's `main` branch on launch, every six hours, and whenever the footer is
clicked. Modified local builds are labeled as development builds instead of being
reported as current.

## Install

```sh
./Scripts/install.sh
```

The installer rebuilds and verifies the app, copies it to
`/Applications/Codex Pace.app`, installs the user LaunchAgent at
`~/Library/LaunchAgents/com.andrew.codex-pace.plist`, and launches the app. The
LaunchAgent opens Codex Pace at each graphical login without hiding its window.

Run the terminal report directly with:

```sh
dist/bin/codex-pace
dist/bin/codex-pace --json
```

You can also launch the built, uninstalled copy with
`open "dist/Codex Pace.app"`.

## How usage is read

Codex Pace starts the locally installed Codex app server and calls its read-only
`account/rateLimits/read` method. It uses Codex's existing login storage; Codex
Pace does not read, copy, or store authentication tokens.

The app-server protocol is experimental and can change with a ChatGPT/Codex
update. Codex Pace keeps all protocol-specific behavior in
`CodexRateLimitClient` and preserves the last successful reading if a refresh
fails.

Codex is normally found inside `/Applications/ChatGPT.app`. To use a different
binary, set `CODEX_PACE_CODEX_PATH` to its absolute path.

Official OpenAI documentation identifies the usage dashboard and `/status` in an
active Codex CLI session as the supported ways to view current usage:
<https://learn.chatgpt.com/docs/pricing#where-can-i-see-my-current-usage-limits>

## License

Codex Pace is available under the MIT License. See [LICENSE](LICENSE).
