#!/usr/bin/bash
# Link the files of this repository into the places where they are used.
# Safe to run again: links that are already correct are left alone, and any
# other file in the way is renamed to *.bak first.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link() {
    local src="$repo/$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
        echo "ok      $dest"
        return
    fi
    if [[ -e "$dest" || -L "$dest" ]]; then
        echo "backup  $dest -> $dest.bak"
        mv "$dest" "$dest.bak"
    fi
    ln -s "$src" "$dest"
    echo "linked  $dest -> $src"
}

link bin/mq ~/.local/bin/mq
link manuq.just ~/.local/share/just/manuq.just
link bash/mq-completion.sh ~/.bashrc.d/mq-completion.sh
