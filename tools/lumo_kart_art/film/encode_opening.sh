#!/bin/sh
# The Godot capture writes frame-000.jpg through frame-143.jpg at 24 fps.
# Keep the score and one-shots on the game's existing volume and focus controls.
set -eu
frames_dir=${1:?Usage: encode_opening.sh FRAME_DIRECTORY}
repository=$(cd "$(dirname "$0")/../../.." && pwd)
test -s "$frames_dir/frame-143.jpg"
ffmpeg -hide_banner -loglevel error -y -framerate 24 -start_number 0 -i "$frames_dir/frame-%03d.jpg" \
  -frames:v 144 -an -c:v libtheora -b:v 3400k -g 24 -pix_fmt yuv420p \
  "$repository/assets/kart/track_stage/clips/windwerk_auftakt.ogv"
