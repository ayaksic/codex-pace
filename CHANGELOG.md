# Changelog

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
