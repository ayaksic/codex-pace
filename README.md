# Codex Pace

Codex Pace compares the percentage of Codex's seven-day usage allowance remaining
with the percentage of the current seven-day window remaining.

> Codex Pace is an independent, unofficial community project. It is not
> affiliated with, endorsed by, or sponsored by OpenAI. Codex and OpenAI are
> trademarks of their respective owners.

The menu bar shows `usage / time`, so `82 / 83.0` means 82% of usage and roughly
83% of the week remain. Click it for the exact values, pace, and reset time.

## Build

```sh
./Scripts/build-app.sh
```

This creates:

- `dist/Codex Pace.app`
- `dist/bin/codex-pace`

## Install

```sh
./Scripts/install.sh
```

The installer rebuilds and verifies the app, copies it to
`/Applications/Codex Pace.app`, installs the user LaunchAgent at
`~/Library/LaunchAgents/com.andrew.codex-pace.plist`, and launches the app in
the background. The LaunchAgent opens Codex Pace at each graphical login.

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
