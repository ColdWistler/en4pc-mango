#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check the locked state *first*: a lookup against a locked collection makes the
# keyring daemon pop a password prompt, which is what users see right after a
# login that had no password (SDDM autologin, or a keyring PAM never unlocked it).
# Reporting "locked" without touching secret-tool keeps the session silent; the
# data is then read once the keyring is actually open.
if ! "${SCRIPT_DIR}/is_unlocked.sh" 2>/dev/null; then
    echo 'locked'
    exit 2
fi

data=$(secret-tool lookup 'application' 'illogical-impulse')
if [[ -z "$data" ]]; then
    echo 'not found'
    exit 1
fi
echo "$data"
