#!/usr/bin/bash
# Open files in the running Emacs (Flatpak), or start Emacs with the prelude
# config if none is running.
#
# The running Emacs is reached through the socket that
# emacs/flatpak-server.el creates.
set -euo pipefail

app="org.gnu.emacs//stable"
socket="${XDG_RUNTIME_DIR}/app/org.gnu.emacs/server"

if [[ -S "$socket" ]]; then
    client=(flatpak run --command=emacsclient "$app" --socket-name="$socket" --no-wait)
    if (( $# )); then
        "${client[@]}" "$@" && exit 0
    else
        "${client[@]}" --eval '(select-frame-set-input-focus (selected-frame))' > /dev/null && exit 0
    fi
    # The socket can be left behind by an Emacs that didn't exit cleanly.
    echo "Couldn't reach the running Emacs, starting a new one." >&2
fi

exec flatpak run "$app" --init-dir ~/repos/prelude "$@"
