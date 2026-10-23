# Global manuq.just — callable from anywhere via: mq <recipe>

# This repository. manuq.just is symlinked elsewhere, so justfile_directory()
# would point at the link instead.
mq_repo := home_directory() / "repos/mq"

# List available recipes
default:
    @just --justfile ~/.local/share/just/manuq.just --list

# ── Modules ──────────────────────────────────────────────

# Recipes of other justfiles, run with their own directory as working directory.
# For example: mq notes do-sync
mod notes "~/manuq-notes"

# ── System ───────────────────────────────────────────────

# Update Flatpak apps
flatpak-update:
    flatpak update -y

# Show disk usage summary for home directory
disk:
    du -sh ~/* ~/.local 2>/dev/null | sort -rh | head -20

# ── Git shortcuts ────────────────────────────────────────

# Git status
gs:
    git status

# Git log (compact)
gl:
    git log --oneline --graph --decorate -20

# ── Misc ─────────────────────────────────────────────────

# Serve current directory over HTTP on a given port (default 8000)
serve port="8000":
    python3 -m http.server {{ port }}

# ── Media ────────────────────────────────────────────────

# Encode video to AV1 using VAAPI hardware acceleration (no audio).
# Pass fps to force that output frame rate, for a source whose tagged rate lies.
encode-webm file fps="":
    ffmpeg -vaapi_device /dev/dri/renderD128 -i {{ file }} {{ if fps == "" { "" } else { "-r " + fps } }} -vf 'format=nv12,hwupload' -c:v av1_vaapi -rc_mode VBR -b:v 3M -an {{ without_extension(file) }}.webm

# Encode video to AV1 (VAAPI) with Opus audio.
# Pass fps to force that output frame rate, for a source whose tagged rate lies.
encode-webm-audio file fps="":
    ffmpeg -vaapi_device /dev/dri/renderD128 -i {{ file }} {{ if fps == "" { "" } else { "-r " + fps } }} -vf 'format=nv12,hwupload' -c:v av1_vaapi -rc_mode VBR -b:v 3M -c:a libopus -b:a 128k {{ without_extension(file) }}.webm

# ── Editors ──────────────────────────────────────────────

# Open files in the running Emacs (Flatpak), or launch it with the prelude config
emacs *args:
    @"{{ mq_repo }}/scripts/emacs.sh" {{ args }}

# ── Threadbare ───────────────────────────────────────────

threadbare_dir := home_directory() / ".var/app/org.godotengine.Godot/data/godot/app_userdata/Threadbare"

# Checkout of the Threadbare repository.
threadbare_repo := home_directory() / "godot-projects/threadbare"

# Query for every pull request. Each recipe below appends its own filters.
threadbare_pulls_url := "https://github.com/endlessm/threadbare/pulls?q=is%3Apr"

# Select a saved_game_*.tres snapshot and set it as the active saved_game.tres
threadbare-restore-state:
    @"{{ mq_repo }}/scripts/threadbare-state.sh" restore "{{ threadbare_dir }}"

# Save the active saved_game.tres as a new named snapshot (saved_game_<name>.tres)
threadbare-save-state:
    @"{{ mq_repo }}/scripts/threadbare-state.sh" save "{{ threadbare_dir }}"

# Encode the last movie recording into the XDG videos directory, without audio
threadbare-encode-last-recording:
    @"{{ mq_repo }}/scripts/threadbare-encode-recording.sh" "{{ threadbare_dir }}"

# Encode the last movie recording into the XDG videos directory, with audio
threadbare-encode-last-recording-audio:
    @"{{ mq_repo }}/scripts/threadbare-encode-recording.sh" --audio "{{ threadbare_dir }}"

# Print the Co-authored-by trailer for a GitHub user, to paste into a commit message
threadbare-get-coauthored username:
    #!/usr/bin/bash
    set -euo pipefail
    # Falls back to GitHub's own noreply address, built from the numeric id, for
    # users with no public email.
    author=$(gh api --jq '(.name // .login) + " <" + (.email // (.id | tostring) + "+" + .login + "@users.noreply.github.com") + ">"' "/users/{{ username }}")
    echo "Co-authored-by: $author"

# Open the Threadbare pull requests, most recently updated first, in a browser
threadbare-pulls-updated:
    @xdg-open "{{ threadbare_pulls_url }}+sort%3Aupdated-desc"

# Open the Threadbare pull requests that still need a review, in a browser
threadbare-pulls-review-required:
    @xdg-open "{{ threadbare_pulls_url }}+state%3Aopen+review%3Arequired"

# Copy MANUQ/daily-report.md to the clipboard as rich text, to paste in Slack
threadbare-report-to-clipboard:
    @"{{ mq_repo }}/scripts/report_to_slack.py" "{{ threadbare_repo }}/MANUQ/daily-report.md"
