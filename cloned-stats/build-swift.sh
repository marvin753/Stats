#!/bin/bash
# Build Stats Swift app from command line

cd "$(dirname "$0")"

echo "🔨 Building Stats app..."

xcodebuild -project Stats.xcodeproj \
  -scheme Stats \
  -configuration Debug \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

if [ $? -eq 0 ]; then
  echo "✅ Build succeeded!"
  echo "📍 Binary: build/Build/Products/Debug/Stats.app"
else
  echo "❌ Build failed!"
  exit 1
fi
