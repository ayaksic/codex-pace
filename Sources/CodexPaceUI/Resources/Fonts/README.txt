Local typography assets

Place licensed ABCAreal-Regular.ttf, ABCAreal-Medium.ttf, and ABCAreal-Bold.ttf
here before building. These binaries are deliberately Git-ignored. SwiftPM
includes local copies in its resource bundle; build-app.sh carries that bundle
into the application. Builds without them use the macOS system font.

Do not distribute font-containing builds without the appropriate font rights.
