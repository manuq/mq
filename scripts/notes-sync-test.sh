#!/usr/bin/bash
# Test the automatic sync of the notes between two copies on this
# computer, as if they were two devices: ~/manuq-notes and a second copy.
#
# Each copy syncs through its own manuq-notes-sync@<path>.path, which
# sends local changes right away. The test changes a markdown file in one
# copy and waits until the change reaches the remote. Then it starts the
# sync of the other copy, as its periodic timer would, and checks that the
# change arrived. Then it does the same in the opposite direction.
set -euo pipefail

first_copy="$HOME/manuq-notes"
second_copy="$HOME/manuq-notes-second-device"
remote="$(< "$HOME/.config/manuq-notes/remote")"
test_file="pages/sync-test.md"
# The service waits 30 seconds before syncing, then takes a few seconds.
timeout_seconds=120

just_in() {
    just --justfile "$1/justfile" --working-directory "$1" "${@:2}"
}

service_for() {
    echo "manuq-notes-sync@$(systemd-escape --path "$1").service"
}

# Set up the second copy like a new device: an empty folder with only the
# justfile, then its first-sync recipe.
if [[ ! -d "$second_copy" ]]; then
    echo "Creating the second copy in $second_copy"
    mkdir "$second_copy"
    ln -s "$HOME/repos/mq/manuq-notes/justfile" "$second_copy/justfile"
    just_in "$second_copy" first-sync
fi

for copy in "$first_copy" "$second_copy"; do
    just_in "$copy" enable-automatic-sync
done

wait_until() {
    local description="$1" waited=0
    shift
    until "$@"; do
        if (( waited >= timeout_seconds )); then
            echo "FAILED: $description didn't happen in ${timeout_seconds}s" >&2
            echo "Check the logs with: journalctl --user -u 'manuq-notes-sync@*'" >&2
            return 1
        fi
        sleep 5
        waited=$((waited + 5))
    done
    echo "OK: $description, after about ${waited}s"
}

remote_has() {
    [[ "$(rclone cat "$remote/$test_file" 2>/dev/null)" == "$1" ]]
}

copy_has() {
    [[ -f "$1/$test_file" && "$(cat "$1/$test_file")" == "$2" ]]
}

check_direction() {
    local from="$1" to="$2"
    local content="Sync test from ${from/#"$HOME"/\~} at $(date --iso-8601=seconds)"
    echo "Writing to ${from/#"$HOME"/\~}/$test_file"
    printf '%s\n' "$content" > "$from/$test_file"
    wait_until "the change reached the remote" remote_has "$content"
    systemctl --user start "$(service_for "$to")"
    wait_until "the change reached ${to/#"$HOME"/\~}" copy_has "$to" "$content"
}

check_direction "$first_copy" "$second_copy"
check_direction "$second_copy" "$first_copy"
echo "Both directions work."
