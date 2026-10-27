# Codex Pace

Codex Pace compares the percentage of Codex's seven-day usage allowance remaining
with the percentage of the current seven-day window remaining.

> Codex Pace is an independent, unofficial community project. It is not
> affiliated with, endorsed by, or sponsored by OpenAI. Codex and OpenAI are
> trademarks of their respective owners.

Codex Pace opens as a regular Dock app with one main window. The menu bar also
shows `usage / time`, so `82% / 83.0%` means 82% of usage and roughly 83% of
the week remain. The top row uses the same order. Click it for the exact values,
pace, and reset time. When the pace
says **Slow down**, the **Stop until** row shows how long it would take to get
back on pace if weekly usage stopped increasing, followed by the date and time
when usage could resume. The **Run out at** row beneath it shows when usage
would reach 0% if the average consumption rate since the window began continued
unchanged, as both a countdown and timestamp. At 0% usage remaining, the pace
label says **Stopped**.

Countdowns keep seconds visible. The next-update countdown appears in the toolbar;
its exact timestamp is available in its help text. Build details and the update
check open from the compact version and status icon in the toolbar. The status icon retains update status without a separate Latest label or information icon.

The projected runout calculation uses the fixed **Next update** timestamp as its
observation point. Its timestamp therefore stays put between refreshes while the
countdown ticks, then recalculates after the next usage reading. Refreshes happen
every 60 seconds at a displayed 2% or higher weekly usage remaining, and every
15 seconds at 1% or 0%. The next-update countdown uses the same interval.

Codex Pace shows a separate alert window when Codex explicitly reports that
included usage is unavailable, weekly usage remaining is 0%, and the usage-credit
balance decreases between fresh readings for the same account and weekly window.
The alert appears once per exhaustion period, including across relaunches, and
updates continue while it is open. A displayed 0% alone does not trigger it.
If Codex omits account identity, included-usage permission, or a valid balance,
Codex Pace cannot confirm credit consumption and does not alert. The balance is
the Codex usage-credit balance; this does not monitor separate API billing or
stop active Codex work.

Codex Pace also shows a separate alert when weekly usage changes from below 100%
to exactly 100% remaining. The alert stays visible until dismissed, and refreshes
continue while it is open. Repeated readings at 100% do not repeat the alert.
The last reading is saved separately for each known account so resets can be
detected across relaunches. A first reading at 100% without an earlier reading
does not trigger an alert. Reset estimates and countdowns alone do not trigger it.

Use the window button in the popover header to focus the main Codex Pace window.
The window shares the menu bar's live reading and refresh cycle. Closing it
leaves the app running; click its Dock icon to reopen the window.
Use the `2×` control in the main window to double the window and everything
inside it for viewing from farther away. The selection is remembered; use `1×`
to return to the standard size. Near a display's right edge, the window expands
left and keeps that right edge in place when returning to `1×`. The menu-bar
popover stays compact. You can also drag the main window's edges or corners to
resize it with its content aspect ratio locked. Content scales with the width;
additional rows scroll vertically within the chosen size.
After a manual resize, content updates preserve your chosen window size. The
1× and 2× presets resize the window once to fit the content and establish its
aspect ratio. Subsequent layout measurements and content updates do not resize
the main window.
On launch, the window fits once after its first usage reading arrives, unless it
has already been manually resized while waiting.

Use the calendar-and-clock button in the header when a one-off usage reset is
expected before the timestamp reported by Codex. Codex Pace shows the manual
value as **Reset by (est.)**, remembers it across launches, and automatically
returns to the Codex-reported timestamp after the estimate passes or Codex
reports that the weekly usage allowance has reset to 100% remaining.

Each available banked reset is always visible as a **Banked reset** row, with its expiration countdown and timestamp. When a known banked reset expires
before the natural reset, the main reset row becomes **Reset expiry** and
counts down to that earlier deadline. Codex Pace preserves the server's
authoritative available count even when the server omits or caps detailed
expiration rows. The earliest of a banked-reset expiration, manual estimate, or
regular weekly reset drives the time percentage, both bar views, menu-bar value,
pace, and time-ahead values together. Stoppage time is hidden while the target is
a banked-reset expiration, since expiration does not replenish usage. It remains
available for weekly resets and manual estimates. Percentages retain the seven-day
scale: six days left is 85.7%. The time metric reads **To expiry** or **To estimate**
for an earlier deadline; the unlabeled timeline ends at that deadline; its help and accessibility description identify the target. **Reset at** remains visible separately. When a credit is
used, expires, or becomes unavailable, pacing selects the next applicable target.
The expiration itself does not automatically apply a banked reset.

During each available banked reset's final 12 hours, Codex Pace presents an hourly
warning at 12, 11, …, 1 hour remaining. A floating window comes forward with a sound
and an attention request, and remains until acknowledged. Acknowledgment does not
disable the next hourly warning. Simultaneous warnings share one window; hourly
history for known accounts survives relaunches. Warnings require Codex Pace to be
running and the Mac awake. After sleep or a refresh failure, warnings continue
from the last known expiration with availability explicitly labeled as last
confirmed until refreshed. Missed hours produce one current warning, not a
backlog. Unavailable, consumed, expired, or undated credits do not trigger
warnings. Using the reset remains a manual action in Codex.

Usage credits appear separately in both windows, using the balance from the same
Codex refresh. A failed refresh labels the retained reading **Last known**;
missing or invalid balances show **Credits unavailable**, rather than zero.
Click the expiration date (or **Set expiration** when absent) to save a local `YYYY-MM-DD` calendar date or remove it. The manually entered expiration date is independent of the total:
credits can have different expirations. The countdown ends at **12:00 AM at the start of the selected date**, using this Mac’s time zone and daylight-saving rules. Passing the date shows a zero countdown and does not change the balance or remove the saved date. The visible balance uses whole credits at 1,000 or more and two decimals below 1,000; full source precision remains available in help text and is retained for alerts.
New installations have no manually entered expiration date.

## Build

```sh
./Scripts/build-app.sh
```

This creates:

- `dist/Codex Pace.app`
- `dist/bin/codex-pace`

Each app bundle is stamped with a build number derived from the Git commit count
and the exact source revision. The toolbar status control compares that revision with the public
repository's `main` branch on launch, every six hours, and whenever the control is clicked. Modified local builds are labeled as development builds instead of being
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

## Local fonts

The main interface uses the macOS system font; its three primary percentages use Seravek Medium when available, falling back to the system font. Existing alert and menu-bar typography can still use ABC Areal (Regular, Medium, Bold) when locally supplied. Copy
licensed `ABCAreal-Regular.ttf`, `ABCAreal-Medium.ttf`, and `ABCAreal-Bold.ttf` into
`Sources/CodexPaceUI/Resources/Fonts/` before building. Font binaries are ignored
by Git. They are registered only for the app process and carried into local app
bundles; no system font installation is performed. Builds without the font assets
fall back to the macOS system font. Distribution of builds containing the font
requires appropriate font rights.
