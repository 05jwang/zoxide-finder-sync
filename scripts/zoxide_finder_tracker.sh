#!/bin/bash

# Store the last path to avoid spamming zoxide
last_path=""

echo "Starting Zoxide Finder Tracker..."

while true; do
    current_path=$(osascript -e '
        tell application "Finder"
            if not (exists front window) then return ""
            try
                set target_path to (POSIX path of (target of front window as alias))
                return target_path
            on error
                return ""
            end try
        end tell
    ' 2>/dev/null)

    if [[ -n "$current_path" && "$current_path" != "$last_path" ]]; then
        zoxide add "$current_path"
        
        echo "Scoped: $current_path"
        last_path="$current_path"
    fi

    sleep 2
done
