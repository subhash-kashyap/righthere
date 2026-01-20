#!/bin/bash

APP_NAME="right here"
BUNDLE_ID="com.righthere.app"
BUILD_DIR=".build/apple/Products/Release"
APP_BUNDLE="$APP_NAME.app"

# Clean up
echo "Cleaning up old build..."
rm -rf "$APP_BUNDLE"

# Build the executable
echo "Building $APP_NAME..."
# SPM doesn't like spaces in target names well, but let's see. 
# If it fails, I'll rename the target to righthere and the display name to "right here"
swift build -c release --arch arm64 --arch x86_64

# Create the app bundle structure
echo "Creating $APP_BUNDLE..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy the binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy the Info.plist
cp "Info.plist" "$APP_BUNDLE/Contents/"

echo "$APP_NAME built successfully at ./$APP_BUNDLE"
echo "---"
echo "To run and see logs:"
echo "./$APP_BUNDLE/Contents/MacOS/right\ here"
echo "---"
echo "Attempting to register Services..."
/System/Library/CoreServices/pbs -update
