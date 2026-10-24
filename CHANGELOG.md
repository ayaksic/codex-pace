# Changelog

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
