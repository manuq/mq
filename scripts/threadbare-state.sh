#!/usr/bin/bash
# Save or restore snapshots of Threadbare's saved_game.tres, or clear the
# saved game and the settings to start fresh.
#
# Usage: threadbare-state.sh save|restore|clear <user data dir>
#
# Snapshots are stored next to it as saved_game_<name>.tres. Clearing keeps
# them.
set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") save|restore|clear <user data dir>" >&2
    exit 2
}

[[ $# -eq 2 ]] || usage
action=$1
dir=$2

save() {
    if [[ ! -f "$dir/saved_game.tres" ]]; then
        echo "No saved_game.tres found in $dir"
        exit 1
    fi
    name=$(gum input --placeholder="my_state" --prompt="New snapshot name: ")
    [[ -z "$name" ]] && echo "Cancelled." && exit 0
    # Prefix with saved_game_ so the snapshot is picked up by restore, which
    # only lists files matching saved_game_*.tres.
    dest="$dir/saved_game_${name}.tres"
    if [[ -e "$dest" ]]; then
        gum confirm "saved_game_${name}.tres already exists. Overwrite?" || { echo "Cancelled."; exit 0; }
    fi
    cp "$dir/saved_game.tres" "$dest"
    echo "✔ Copied saved_game.tres → saved_game_${name}.tres"
    echo "  (prefixed with 'saved_game_' so 'mq threadbare-restore-state' can find it)"
}

restore() {
    # Without nullglob, an unmatched pattern stays as a literal file name.
    shopt -s nullglob
    files=( "$dir"/saved_game_*.tres )
    shopt -u nullglob
    if [[ ${#files[@]} -eq 0 ]]; then
        echo "No saved_game_*.tres snapshots found in $dir"
        exit 1
    fi
    names=()
    for f in "${files[@]}"; do
        names+=("$(basename "$f")")
    done
    choice=$(gum choose --header="Select a saved game to restore:" "${names[@]}")
    [[ -z "$choice" ]] && echo "Cancelled." && exit 0
    cp "$dir/$choice" "$dir/saved_game.tres"
    echo "✔ Copied $choice → saved_game.tres"
}

clear() {
    files=()
    for name in saved_game.tres settings.cfg; do
        [[ -f "$dir/$name" ]] && files+=("$name")
    done
    if [[ ${#files[@]} -eq 0 ]]; then
        echo "Nothing to clear in $dir"
        exit 0
    fi
    echo "This deletes, in $dir:"
    printf '  %s\n' "${files[@]}"
    echo "The saved_game_*.tres snapshots are kept."
    gum confirm "Delete them?" --default=false || { echo "Cancelled."; exit 0; }
    for name in "${files[@]}"; do
        rm "$dir/$name"
        echo "✔ Deleted $name"
    done
}

case $action in
    save) save ;;
    restore) restore ;;
    clear) clear ;;
    *) usage ;;
esac
