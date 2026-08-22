#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
built_app="$project_dir/dist/Codex Pace.app"
installed_app="/Applications/Codex Pace.app"
launch_agent_source="$project_dir/Resources/com.andrew.codex-pace.plist"
launch_agent_dir="$HOME/Library/LaunchAgents"
launch_agent="$launch_agent_dir/com.andrew.codex-pace.plist"
launch_domain="gui/$(id -u)"
launch_service="$launch_domain/com.andrew.codex-pace"

"$project_dir/Scripts/build-app.sh"

case "$installed_app" in
    "/Applications/Codex Pace.app") ;;
    *)
        echo "Refusing to install to an unexpected app path: $installed_app" >&2
        exit 1
        ;;
esac

/usr/bin/ditto "$built_app" "$installed_app"
/usr/bin/codesign --verify --deep --strict "$installed_app"

/bin/mkdir -p "$launch_agent_dir"
/usr/bin/install -m 0644 "$launch_agent_source" "$launch_agent"
/usr/bin/plutil -lint "$launch_agent"

/bin/launchctl bootout "$launch_domain" "$launch_agent" 2>/dev/null || true
/bin/launchctl bootstrap "$launch_domain" "$launch_agent"
/bin/launchctl enable "$launch_service"

/usr/bin/open -a "$installed_app"

echo "$installed_app"
echo "$launch_agent"
