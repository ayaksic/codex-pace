# codex-pace semantic-version baseline

Adopted locally on 2026-10-01: **1.11.1**, for source through `b2bbfb8563a5763d9c206b7349b36c9d46f0dc5a`.

This is a retrospective estimate, not a claim these numbered releases were published. Complete first-parent history was reviewed, with imported histories where applicable. Initial usable application is the 1.0 era. Minor increments represent grouped capabilities, not commit counts; related fixes belong to their batch. No intentional breaking application contract was established, so MAJOR remains 1. Do not rewrite history or create historical release tags.

| Batch | Capability | Commit anchors |
| --- | --- | --- |
| 1 | Timing detail and live resets | `37fb419,4e8fb7e` |
| 2 | Segmented percentage bars | `2652b77` |
| 3 | Pop-out window and catch-up timing | `eef7e4d` |
| 4 | Time-ahead guidance | `79ea40e` |
| 5 | Dock/main-window operation | `4671b45,425a02a` |
| 6 | Second-resolution timing and alignment | `abeb9e2,c467b13` |
| 7 | Double-size window | `71d009d` |
| 8 | Estimated and banked resets | `4a651aa` |
| 9 | Installed update status | `d363ac1` |
| 10 | Projected runout | `8384f8d` |
| 11 | Weekly timeline | `91dd8cf,571f107` |

One coherent trailing sizing repair batch (four commits): ccbbe3c,736d389,494573b,b2bbfb8; location/icon changes are not separate features.

## Version authority

`Version.xcconfig` owns `APP_RELEASE_VERSION`. Native targets inherit it; scripts and generated web/package surfaces derive it. Platform build numbers and immutable commits remain separate. Update this source and CHANGELOG.md together for future releases. No deployment or installation is implied by this local adoption.

Derived labels can be refreshed with `python3 scripts/sync-version.py` and verified with `--check` (the `Scripts` spelling is canonical for Codex Pace and Sobriety Timer). Keep these generated copies synchronized when changing the authoritative source.
