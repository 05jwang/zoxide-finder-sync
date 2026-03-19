#!/bin/bash

APP_NAME="ZoxideFinderSync"
LABEL="com.jerrywang.ZoxideFinderSync"
INSTALL_DIR="$HOME/.local/bin"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/$LABEL.plist"
EXECUTABLE_PATH="$INSTALL_DIR/$APP_NAME"
USER_ID=$(id -u)

echo "Starting uninstallation for $APP_NAME..."

# 1. Stop and unregister the service
if [ -f "$PLIST_PATH" ]; then
    echo "Stopping the background service..."
    launchctl bootout gui/"$USER_ID" "$PLIST_PATH" 2>/dev/null || true
fi

# 2. Remove the Launch Agent plist
echo "Removing Launch Agent..."
rm -f "$PLIST_PATH"

# 3. Remove the executable
echo "Removing executable..."
rm -f "$EXECUTABLE_PATH"

# 4. (Optional) Prompt to remove logs and settings
read -p "Do you want to delete application logs and settings (UserDefaults)? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing logs..."
    rm -rf "$HOME/Library/Logs/$APP_NAME"
    
    echo "Removing settings..."
    defaults delete com.jerrywang.ZoxideFinderSync 2>/dev/null || true
fi

echo "Uninstallation complete."
