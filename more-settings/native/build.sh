#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
destination="build/native/more_settings_audio.hdll"
mkdir -p "$(dirname "$destination")"
x86_64-w64-mingw32-gcc -std=c11 -O2 -Wall -Wextra -Werror -shared -static-libgcc \
  native/event_volume.c -o "$destination"
# The plugin exports precisely two HashLink primitive registration functions.
x86_64-w64-mingw32-objdump -p "$destination" > build/native/exports.txt
for primitive in hlp_event_get_volume hlp_event_set_volume; do
  grep -q "$primitive" build/native/exports.txt
done
