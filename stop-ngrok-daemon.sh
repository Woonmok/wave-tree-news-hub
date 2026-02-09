#!/bin/bash
set -euo pipefail

PLIST_FILE="$HOME/Library/LaunchAgents/com.ngrok.plist"

if launchctl list | grep -q "com.ngrok.tunnel"; then
  launchctl unload "$PLIST_FILE"
  echo "ngrok LaunchAgent unloaded"
else
  echo "ngrok LaunchAgent not loaded"
fi

if [ -f "$PLIST_FILE" ]; then
  rm "$PLIST_FILE"
  echo "plist removed: $PLIST_FILE"
fi
