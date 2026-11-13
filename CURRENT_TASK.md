# Current task — 2026-11-13

Prepared local 2.2.0 with a 30-minute snooze on the included-usage exhaustion
alert. Snooze is saved per account and survives relaunch. The next confirmed
credit decrease after expiry can show the alert again. OK and window close keep
the existing once-per-exhaustion behavior. The installed app is still 2.1.1.

Validation: all 112 tests passed, and a native synthetic preview confirmed the
alert layout. Version synchronization and git diff --check passed.

Storage: reused the existing /Users/andrew/Documents/codex-pace/.build cache.
This task retained credit-alert-snooze-2.2.0.png (40 KB) and
credit-alert-snooze-2.2.0-tests.log (about 24 KB) there as validation evidence.

## Previous task — 2026-11-12

Prepared 2.1.1 to prevent normal refresh metadata from erasing planned idle hours.
Removed exact deadline and pacing-target equality from idle-plan validity. Missing
account information and a temporary zero-length target preserve the saved plan.
Detected usage resets, completed weekly rollovers, and confirmed account switches
still clear it. Existing 2.1.0 persisted estimates decode without migration.

Validation: a one-second deadline correction reproduced unwanted clearing before
the fix; the regression now passes. All 111 tests pass (102 UI/model, 9 core),
including real-reset clearing, restored estimates, target changes, absent identity,
and weekly rollover. Three live reads with unchanged metadata preserved a sample
estimate in an isolated model; the user's exact live clearing event was not
reproduced. Native application inspection timed out, so no live UI verification
is claimed for this patch. Version synchronization and git diff --check passed.
Build/test artifacts reuse .build and dist; temporary diagnostic source and
process sample are under the chat's work directory. The temporary live diagnostic
test was removed before publication. Continue the authorized commit/push workflow;
Git history records the patch identity.

## Previous release — 2026-11-12

Prepared version 2.1.0 with manual planned-idle projections. Confirmed saved idle
hours clear when a usage reset is detected, including after relaunch. Also clear
an unsaved value in an open editor on reset, preventing Save from restoring the
previous window's hours. Updated the authoritative release version, derived
surfaces, README, and changelog. Commit and push to origin/main are authorized;
Git history records the publication identity.

Regression coverage includes reset notification without a saved estimate,
persisted clearing after relaunch, and existing pacing/persistence/target cases.
The slow-start test now gates the first response explicitly instead of assuming
that the native UI suite will schedule it within a fixed delay.

Validation: all 109 tests passed (100 UI/model and 9 core), including native
spacing and resize checks. Version synchronization and git diff --check passed.
Build outputs and test logs reuse the existing .build and dist directories.

## Previous local prototype — 2026-11-12

Implemented and installed local 2.0.15 with a planned-idle-hours editor in the
moon toolbar control. Manual remaining idle time adjusts the seven-day pace,
bars, menu percentage, extra pause and runout forecast; active time and idle
hours are visible separately. Actual usage and reset timestamps stay unchanged.
Fractional hours, presets, edit/clear, persistence, and automatic invalidation
on account/window/target/reset changes are supported. Runout assumes idle occurs
before exhaustion. Users reduce or clear remaining idle time after a break.

Validation: full suite passed (97 UI/model + 9 core tests). After a final
accessibility description correction and startup persistence guard, all six
focused idle tests passed, including a slow initial fetch spanning timer ticks.
Native preview verified save, clear, invalid-input blocking, and expected pace
changes. The original spacing and resize regressions were fixed by sizing the
new symbol within the existing toolbar. Release build, code signature, version
synchronization, and git diff --check passed. Installed 2.0.15 in /Applications,
restarted, and verified the new editor against the live usage reading. Editor
is open at zero idle hours for the user to choose. Git changes remain uncommitted
and unpushed, so the app correctly identifies itself as a development build.

Storage: reused the repository .build cache, logs, preview PNG and dist bundle.
A preview wrapper and prior installed 2.0.14 backup are under
/Users/andrew/Documents/Codex/2026-11-12/cod/work. Preview process was closed.

## Previous task — 2026-11-10

Prepared local 2.0.14: countdown numbers no longer use leading zeroes. Existing
18-point, right-aligned number cells, unit widths, and shared gaps remain intact,
so a single digit retains the space previously occupied by a two-digit number.
Updated the authoritative version, derived labels, changelog, and README.

Validation: all seven focused countdown/duration/column tests passed, including
native SwiftUI render sizing, hidden leading units, and preserved day/hour
columns. Native synthetic previews at 1× and 2× visually confirm unpadded
single-digit and zero values with aligned suffixes. Version synchronization and
git diff --check passed. Commit and push to origin/main authorized; Git history
records the publication identity. Installation has not been requested or
performed for this change; the running installed application remains unchanged.

Storage: reused /Users/andrew/Documents/codex-pace/.build as the existing build
cache (approximately 698 MB). Retained synthetic preview evidence in that directory as
countdown-no-zeroes-1x.png and countdown-no-zeroes-2x.png (approximately 376 KB combined),
owned by this task. No new directories, source copies, or worktrees created.

## Previous task — 2026-11-09

Fixed horizontal drift when repeatedly switching between 1× and 2×. Both
directions now retain the left edge, except for the existing onscreen adjustment
on expansion. Prepared local version 2.0.13 with synchronized release labels,
changelog, and README. Commit and push to `origin/main` authorized; installation
has not been requested or performed. Git history records the publication identity.

Validation: the new native-window regression failed before the fix and passed
afterward. All 10 targeted resize/placement tests passed, including repeated
cycles, right-edge starts, standard/full-size title bars, delayed measurements,
row changes, manual sizing, and screen clamping. Version synchronization and
`git diff --check` passed. Clicked repeated 1×/2× cycles in the isolated SwiftUI
preview and inspected both rendered sizes. Preview uses synthetic data with
polling disabled; its build revision is a fixture, not release provenance.
Preview processes were closed after checking. Installed-app verification remains
pending a separately authorized installation.

Storage owned by this task: reused `/Users/andrew/Documents/codex-pace/.build`
(approximately 783 MB total existing/reused build cache). Created
`/Users/andrew/Documents/codex-pace/.build/CodexPaceResizePreview.app`
(approximately 2.9 MB), a reusable local preview wrapper required for native UI
automation; generated output, not an installed application. No source snapshots,
dependency copies, or extra worktrees created.
