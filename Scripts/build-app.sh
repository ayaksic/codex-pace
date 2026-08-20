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
swift "$project_dir/Scripts/generate-icon.swift" \
    "$project_dir/Resources/AppIconSource.png" \
    "$resources_dir/AppIcon.icns"

codesign --force --sign - "$app_bundle"
codesign --verify --deep --strict "$app_bundle"

echo "$app_bundle"
echo "$cli_dir/codex-pace"
