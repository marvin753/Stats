#!/bin/bash
#
# Build Stats app with screenshot support (without modifying Xcode project)
#

echo "🔨 Building Stats app with screenshot support..."

cd "$(dirname "$0")"

# Build with xcodebuild, explicitly including the new files
xcodebuild \
  -project Stats.xcodeproj \
  -scheme Stats \
  -configuration Debug \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  OTHER_SWIFT_FLAGS="-I Stats/Modules" \
  build

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Build succeeded!"
else
  echo ""
  echo "❌ Build failed!"
  exit 1
fi
