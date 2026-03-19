#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

APP_NAME="ZoxideFinderSync"
LABEL="com.jerrywang.ZoxideFinderSync"
INSTALL_DIR="$HOME/.local/bin"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/$LABEL.plist"
EXECUTABLE_PATH="$INSTALL_DIR/$APP_NAME"
USER_ID=$(id -u)

echo "Starting installation for $APP_NAME..."

# 1. Build the release binary
echo "Building Swift package (Release mode)..."
swift build -c release

# 2. Prepare installation directories
echo "Preparing directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$PLIST_DIR"

# 3. Move the binary
echo "Installing executable to $INSTALL_DIR..."
# The Swift build output path might vary slightly based on CPU architecture
BUILD_PATH=$(swift build -c release --show-bin-path)
cp "$BUILD_PATH/$APP_NAME" "$EXECUTABLE_PATH"

# 4. Generate the .plist file dynamically to capture the correct $HOME
echo "Generating Launch Agent plist..."
cat <<EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$EXECUTABLE_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/dev/null</string>
    <key>StandardErrorPath</key>
    <string>/dev/null</string>
</dict>
</plist>
EOF

# 5. Load the service
echo "Registering and starting the background service..."
# Unload if it already exists to prevent errors during updates
launchctl bootout gui/"$USER_ID" "$PLIST_PATH" 2>/dev/null || true
launchctl bootstrap gui/"$USER_ID" "$PLIST_PATH"

echo "Installation complete! $APP_NAME is now running in the background."
echo "Logs can be found at: ~/Library/Logs/ZoxideFinderSync/ZoxideFinderSync.log"
