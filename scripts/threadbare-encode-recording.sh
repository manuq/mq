#!/usr/bin/bash
# Encode the recording.ogv written by Godot's movie writer to .webm, and move
# it out of the game's user data directory into the XDG videos directory.
#
# Usage: threadbare-encode-recording.sh [--audio] <user data dir>
set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") [--audio] <user data dir>" >&2
    exit 2
}

recipe=encode-webm
if [[ ${1:-} == --audio ]]; then
    recipe=encode-webm-audio
    shift
fi
[[ $# -eq 1 ]] || usage
dir=$1

src="$dir/recording.ogv"
if [[ ! -f "$src" ]]; then
    echo "No recording.ogv found in $dir"
    exit 1
fi
videos="$(xdg-user-dir VIDEOS)"
# Only the part before the extension is asked for, the output is always .webm.
stem=$(gum input --placeholder="recording" --prompt="Output file name (.webm): ")
stem="${stem:-recording}"
stem="${stem%.webm}"
dest="$videos/${stem}.webm"
# Ask before encoding, so a long encode is not thrown away at the last step.
if [[ -e "$dest" ]]; then
    gum confirm "$dest already exists. Overwrite?" || { echo "Cancelled."; exit 0; }
fi
# Godot tags the recording at movie_writer/fps, but writes fewer frames when
# the game cannot keep up, so players that trust the tag run the video fast
# and it drifts away from the audio. Measure the rate the frames actually
# imply, and encode at that instead.
frames=$(ffprobe -v error -select_streams v -count_frames \
    -show_entries stream=nb_read_frames -of csv=p=0 "$src")
last_pts=$(ffprobe -v error -select_streams v -show_entries packet=pts_time \
    -of csv=p=0 "$src" | tail -1 | tr -d ',')
fps=$(LC_ALL=C awk -v n="$frames" -v t="$last_pts" \
    'BEGIN { if (t > 0 && n > 1) printf "%.3f", (n - 1) / t }')
if [[ -n "$fps" ]]; then
    echo "Source has $frames frames over ${last_pts}s, encoding at $fps fps."
else
    echo "Could not measure the frame rate, leaving it to ffmpeg."
fi
# The ffmpeg settings live in the encode-webm recipes of manuq.just.
mq "$recipe" "$src" "$fps"
mkdir -p "$videos"
mv "$dir/recording.webm" "$dest"
echo "✔ Encoded recording.ogv → $dest"
