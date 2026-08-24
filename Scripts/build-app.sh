#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
app_bundle="$project_dir/dist/Codex Pace.app"
contents_dir="$app_bundle/Contents"
macos_dir="$contents_dir/MacOS"
resources_dir="$contents_dir/Resources"
cli_dir="$project_dir/dist/bin"
build_configuration="${CONFIGURATION:-release}"
build_dir="$project_dir/.build/$build_configuration"
source_revision="$(git -C "$project_dir" rev-parse HEAD 2>/dev/null || true)"
build_number="$(git -C "$project_dir" rev-list --count HEAD 2>/dev/null || true)"
source_state="clean"

if [[ -z "$source_revision" || -z "$build_number" ]]; then
    source_revision="unknown"
    build_number="1"
    source_state="unknown"
elif [[ -n "$(git -C "$project_dir" status --porcelain --untracked-files=normal)" ]]; then
    source_state="modified"
fi

swift build --package-path "$project_dir" --configuration "$build_configuration" --product CodexPaceMenu
swift build --package-path "$project_dir" --configuration "$build_configuration" --product codex-pace

case "$app_bundle" in
    "$project_dir/dist/"*) ;;
    *)
        echo "Refusing to replace an unexpected app path: $app_bundle" >&2
        exit 1
        ;;
esac

rm -rf "$app_bundle"
mkdir -p "$macos_dir" "$resources_dir" "$cli_dir"
cp "$build_dir/CodexPaceMenu" "$macos_dir/Codex Pace"
cp "$build_dir/codex-pace" "$cli_dir/codex-pace"
cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CodexPaceSourceRevision $source_revision" "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CodexPaceSourceState $source_state" "$contents_dir/Info.plist"
swift "$project_dir/Scripts/generate-icon.swift" \
    "$project_dir/Resources/AppIconSource.png" \
    "$resources_dir/AppIcon.icns"

codesign --force --sign - "$app_bundle"
codesign --verify --deep --strict "$app_bundle"

echo "$app_bundle"
echo "$cli_dir/codex-pace"
