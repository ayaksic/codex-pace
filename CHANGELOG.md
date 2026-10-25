# Changelog

## 2.0.3 — 2026-10-25

- Hide the reported "Reset at" row while a manually entered reset estimate is active. Show it again when the estimate is removed or expires; retain banked-reset timing and the existing pacing calculations.

## 2.0.2 — 2026-10-24

- Increase letter spacing on the three large percentages so repeated digits such as `77%` remain visually separated.
- Use the same middle dot between the date and time in every row, including credit expiration.
- Anchor every date separator to the same horizontal position, with fixed date and time fields. Keep timer line heights and baselines stable across changing digits to prevent pixel movement and uneven row spacing.
- Use four-point gaps within percentage/pill and bar/bar pairs, and a shared eleven-point visible gap around the toolbar, metric group, bars, and timing rows. Account for invisible font leading in layout. Keep the release version at 2.0.2.
- Use lowercase ten-point metric-pill labels, horizontal interior padding of seven points, and vertical interior padding of two points.

## 2.0.1 — 2026-10-24

- Widen the shared countdown unit cells to fit the system font's full `m`, preventing its right edge from clipping while keeping day, hour, minute, and second columns aligned.

## 2.0.0 — 2026-10-24

- Build 57: keep build details open across timer and update-status changes by giving only the visible layout ownership of its popover. Fix the timeline fill to the explicit usage blue and use a black-filled, white-outlined diamond. Keep the application version at 2.0.0.
- Replace the window and menu popover with the approved compact 466-point, three-column layout. Use Seravek Medium for the primary percentages with a system-font fallback, and matching system typography for labels, countdowns, and dates.
- Keep countdown unit positions aligned, center the shared hours/minutes/seconds block with an optional day prefix, and move it 14 points right. Use equal six-point peer gaps and remove horizontal section dividers.
- Match the Usage left and Week left pills to their unlabeled bars; retain the alternate timeline without a Week label. Rename the main timing rows Stop until, Run out at, and Reset at.
- Color the usage and time percentages to match their blue/purple pills and bars. Reduce each bar to 50 segments, align separators to physical pixels, and replace the timeline's vertical time marker with a small diamond.
- Combine usage credits, their expiration countdown, and the clickable expiration date on one row. Show whole credits at 1,000 or more and two decimals below 1,000; preserve the original reading for accounting, alerts, and help text. Interpret saved expiration dates as midnight at the start of the selected local date, including daylight-saving transitions.
- Always show available banked resets as individual Banked reset rows, retaining unknown-expiration and omitted-detail disclosures. Remove the collapsible section, count badge, and disclosure arrow.
- Move version/update details to the toolbar, combine update status and build-detail access in one icon, and use a circled X to quit. Retain resizable windows, the 1×/2× presets, editors, refresh, update checks, pacing behavior, and alerts.
- Fit the main window once after the first usage reading arrives, so a full relaunch shows every initial row. Preserve manual sizing while waiting and avoid resizing on subsequent content updates.
- Breaking interface changes: the layout and credit-date cutoff replace the previous presentation, and the obsolete showsBankedResetsInitially view initializer argument is removed.

## 1.17.1 — 2026-10-24

- Stop layout measurements from resizing the main window, preventing snap-back and flicker during manual resizing and preset changes. Fit the main window only on opening or an explicit 1×/2× selection; content updates preserve its size.

## 1.17.0 — 2026-10-24

- Allow manual resizing of the main window with continuous content scaling by width and vertical scrolling when needed. Keep 1× and 2× as quick size presets.
- Hide Stoppage time when the active countdown targets a banked reset's expiration; retain it for weekly resets and manual estimates.
- Enlarge countdown values in the main window and menu popover while preserving aligned day, hour, minute, and second columns.

## 1.16.0 — 2026-10-24

- Refresh the native window and menu popover with ABCAreal typography, aligned countdowns with seconds, quieter timestamps and build details, a toolbar update countdown, and compact metadata. Retain the reset/credit editors, paired-bar/timeline toggle, and banked-reset disclosure.
- Put usage remaining before time remaining in the top metrics and menu-bar text.
- Load locally supplied ABCAreal fonts as process-local resources; keep licensed font binaries out of the public source repository and use the system font when absent.

## 1.15.0 — 2026-10-23

- Target the earliest banked-reset expiration, manual estimate, or weekly reset consistently across time remaining, menu-bar percentages, both bar views, pace, and pace timing. Label expiration and estimate targets explicitly, retain the seven-day percentage scale, and show the regular weekly reset separately.
- Warn at 12, 11, …, 1 hour before each available banked reset expires with a persistent foreground window, sound, and attention request. Group simultaneous warnings, retain hourly warning history across relaunches for known accounts, and stop warnings when fresh readings show a reset is no longer available. Refresh failures preserve warnings with availability labeled as last confirmed; missed hours produce one current warning.

## 1.14.0 — 2026-10-17

- Show a separate, nonblocking alert when a fresh weekly usage reading returns to exactly 100% remaining. Repeated full readings do not repeat the alert; saved readings for each known account preserve detection across relaunches.

## 1.13.0 — 2026-10-14

- Refresh every 15 seconds at a displayed 1% or 0% weekly usage remaining; keep 60-second updates at 2% or higher, including the next-update countdown and projection timestamp.
- Show a separate, nonblocking alert once per exhaustion period when Codex confirms included usage is unavailable and a fresh reading shows a lower usage-credit balance for the same account and weekly window. A displayed 0% alone does not trigger an alert; missing confirmation or balance data remains unknown.

## 1.12.2 – 2026-10-12
- Change refresh interval from 120 seconds to 60 seconds.

## 1.12.1 — 2026-10-01

- Label the manual usage-credit date as an expiration date throughout the display and editor.
- Clarify that usage-credit expiration dates are manually entered, separate from Codex-reported banked reset expirations.

## 1.12.0 — 2026-10-01

- Show live usage credits separately from weekly pacing and banked resets, with last-known labeling after refresh failures.
- Add editable, removable local calendar-date expiration notes without assuming a universal expiration or a gift ledger.

## 1.11.1 — 2026-10-01 retrospective baseline

- Adopt the estimated semantic version for existing capabilities through `b2bbfb8563a5`.
- See [the baseline rationale](docs/VERSION_BASELINE.md) for feature batches, fixes, uncertainty, and history anchors. This does not assert a historical or externally published release.
