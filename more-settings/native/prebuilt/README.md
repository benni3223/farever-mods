# Prebuilt Windows audio plugin

`more_settings_audio.hdll` is the Windows x64 event-volume bridge shipped in
More Settings 1.10.0. Its `event_volume.c` source and `build.sh` are unchanged.
Normal CI builds verify the binary and source checksums, then package this
binary directly. They do not install MinGW or rebuild the bridge.

`SHA256SUMS` covers the binary, source, and build script so a future native-code
change cannot silently ship the previous binary. If the native bridge changes,
rebuild it with MinGW, run its tests, and refresh the bundled binary and hashes:

```sh
# From more-settings/
bash native/build.sh
cc -std=c11 -Wall -Wextra -Werror tests/event_volume_test.c -o build/event-volume-test
build/event-volume-test
cp build/native/more_settings_audio.hdll native/prebuilt/
(cd native/prebuilt && sha256sum more_settings_audio.hdll ../event_volume.c ../build.sh > SHA256SUMS)
```

The binary is built from this repository's source. It contains no game or FMOD
binaries; it resolves the game's already-loaded FMOD API at runtime.
