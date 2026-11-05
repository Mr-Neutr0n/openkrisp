#!/bin/sh
set -eu

fail() {
    echo "Open Krisp: $1" >&2
    exit 1
}

[ "${3:-}" = "/" ] || fail "Only the current startup volume is supported."
[ "$(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null || true)" = "1" ] || fail "An Apple Silicon Mac is required."
version=$(/usr/bin/sw_vers -productVersion)
major=${version%%.*}
case "$major" in ''|*[!0-9]*) fail "Cannot verify the macOS version." ;; esac
[ "$major" -ge 12 ] || fail "macOS 12 or later is required."

app='/Applications/Lab Voice.app'
driver='/Library/Audio/Plug-Ins/HAL/LabVoiceAudio.driver'

plain_parents() {
    parent=$(/usr/bin/dirname "$1")
    while [ "$parent" != "/" ]; do
        [ ! -L "$parent" ] || fail "An installation parent is a symbolic link."
        if [ -e "$parent" ] && [ ! -d "$parent" ]; then
            fail "An installation parent is not a directory."
        fi
        parent=$(/usr/bin/dirname "$parent")
    done
}

plain_parents "$app"
plain_parents "$driver"
for target in "$app" "$driver"; do
    if [ -e "$target" ] || [ -L "$target" ]; then
        fail "A target already exists. This fresh-install package will not replace it."
    fi
done

# Installer writes the two reviewed payload bundles after this preflight.
# There is no postinstall, audio restart, app launch, or model download.
exit 0
