#!/bin/bash
# Claude Code hook: send notifications via cmux
# Falls back to no-op if not running in cmux

# Skip if cmux socket not available
[ -S /tmp/cmux.sock ] || exit 0

EVENT=$(cat)
EVENT_TYPE=$(echo "$EVENT" | jq -r '.hook_event_name // "unknown"')


case "$EVENT_TYPE" in
  "Stop")
    cmux notify --title "Claude Code" --body "Session complete"
    ;;
  "Notification")
    BODY=$(echo "$EVENT" | jq -r '.message // "Notification"')
    cmux notify --title "Claude Code" --subtitle "Notification" --body "$BODY"
    ;;
esac

exit 0
