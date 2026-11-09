# Current task — 2026-11-09

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
