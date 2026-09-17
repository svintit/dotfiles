# Keyboard setup

Piantor Pro (42 keys, beekeeb) with a Miryoku Colemak-DH layout, a custom
Vial firmware, Karabiner rules for the MacBook keyboard, and a Hammerspoon
layer popup.

| Folder | Contents | Restore target |
|---|---|---|
| `vial/` | Saved Vial layout, tap dance, QMK settings | Vial > File > Load saved layout |
| `firmware/` | Built `.uf2`, keymap sources, vial-qmk commit | Flash once per half |
| `hammerspoon/` | Layer popup, HID monitor, layer labels | `~/.hammerspoon/` |
| `karabiner/` | Karabiner config and rule files | `~/.config/karabiner/` |

## Firmware

Use `vial-kb/vial-qmk` at the commit in `firmware/vial-qmk-commit.txt`.
The candidate patch is specific to this Piantor Miryoku layout.

### Current firmware: Space typing guard and same-hand Space

The connected half runs version `0x0204`; the other half runs `0x0203`.
Both flash readbacks passed. Each half's Vial configuration matches its own backup.
2.0.4 only matches the Fun key by layer 6 instead of the literal `LT(6, KC_DELETE)`.
Behaviour is identical for this keymap, so both halves behave the same.
Space uses a 150 ms Flow Tap guard after recent typing. A protected press stays Space until release.
Pause at least 150 ms after typing before pressing Space to start Navigation.
The other thumb keys and immediate Fun shortcuts keep their previous behavior.
Only the USB-connected master processes tap-hold behavior. Updating that half applies this guard to both hands.
Each half holds the same Miryoku layout, so either can take USB.

Use picotool's `--ser` selector when you must target one keyboard half.
Keep device serials, live backups, and validation results outside this repository.
The saved `.vil` file does not include all current keymap changes.

A Backspace switch that read as dead prompted several workarounds. A raw matrix poll
showed matrix position `(7,4)` never closing while its row and column both scanned fine,
so the cause was the switch seating, not firmware. Reseating fixed it; it now works
consistently. The workarounds were undone: Fun-layer digits, the temporary `QK_BOOT`
corner keys, and an unused thumb-swap firmware build. The Space guard, same-hand Space
fix, Raycast shortcut, and the second half's layout copy were kept.

For a future dead key, poll the raw matrix first. `id_switch_matrix_state` (VIA command
`0x02 0x03`) reports the scan buffer before any keycode or layer logic, which separates
hardware from firmware in one step. Pause the Hammerspoon HID monitor first; it holds
the same HID handle.

### Previous roll-safety candidate, USB version 2.0.1

`firmware/piantor-pro-vial-roll-safe.uf2` is a candidate, not a confirmed hardware fix.
The user confirms an earlier left-half flash. The exact installed build is not identified.

| Keys | Candidate behavior |
|---|---|
| A, R, S, T, O, I, E, N, Z | 250 ms tapping term; no Permissive Hold or HOOKP; 150 ms Flow Tap |
| Fun/Delete | HOOKP on; Quick Tap off; a single tap still sends Delete |
| Other thumb layers | Keep the Vial tapping term, Permissive Hold, and Quick Tap settings |

Z keeps its Num-layer hold. Letter-to-thumb combinations get typing priority within the tapping term.
Thumb-to-letter layer combinations keep their existing chordal behavior.
Flow Tap applies only to the nine typing keys, not to thumb-layer activation.
Quick Tap is off for the nine typing keys. Flow Tap still permits rapid repeated letters.

Deliberate home-row shortcuts require a hold of about 250 ms.
After recent typing, allow the 150 ms Flow Tap interval to pass before starting that hold.
A key that Flow Tap selects as a letter stays a letter until release.
These rules reduce ambiguity; they cannot infer every typing intention.

The last device readback shows tapping term 120 ms, Permissive Hold on, global HOOKP off, and Chordal Hold on.
The candidate work does not change those live settings or the saved layout.
Do not disable Permissive Hold globally to address home-row typing errors.
A shorter tapping term activates holds sooner and can increase accidental modifiers.

Vial already defines `HOLD_ON_OTHER_KEY_PRESS_PER_KEY` in `builddefs/build_vial.mk`.
The earlier claim that a missing `rules.mk` entry made the hook dead code was incorrect.
The earlier link error came from duplicate function definitions, not from the compiler flag.

### Build

Start from the pinned source and copy the four keymap files into `keymaps/vial`.
Apply `firmware/patches/qmk_settings-space-typing.patch` to the unmodified pinned source.
Do not apply either older patch first.

```sh
git apply ~/dotfiles/keyboard/firmware/patches/qmk_settings-space-typing.patch
podman run --rm -v "$PWD":/qmk_firmware:Z -w /qmk_firmware \
  -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e 'GIT_CONFIG_VALUE_0=*' \
  --entrypoint make ghcr.io/qmk/qmk_cli:latest -j8 beekeeb/piantor_pro:vial
```

### Check before installation

The QMK simulation checks the candidate's actual callback bodies.
The full suite passes all 535 checks without exclusions. Another 16 timing scenarios check Space and shortcuts.
These checks cover all six `at` + Space release orders and both reproduced failures.
`firmware/piantor-pro-vial-space-safe-verification.zip` contains the updated suite and build commands.
Simulation results do not prove physical switch timing, installed firmware identity, or host shortcut behavior.

Before a flash, export the live Vial layout and settings. The saved `.vil` can differ from the live device.
Unplug USB before connecting or disconnecting TRRS. Never hot-plug the TRRS cable.
Connect each target half directly by USB for its firmware update.
The temporary Boot keys occupy base-layer matrix positions `(0,0)` and `(4,0)`.
Either corner reboots the USB-connected master. Read that half's live keymap after moving USB.
Tap and release the corner key. Do not hold the key while the firmware restarts.
Restore the saved corner assignments after installation.
Confirm the RP2040 bootloader device before any write; re-identify the device for each half.
If a raw write is necessary, unmount the verified bootloader disk first. Never write to a guessed disk or mountpoint.
Bootmagic can reset saved configuration, so retain the live backup.

After installation, read the USB release number. The Space typing guard reports `0x0202` (2.0.2).
Then check fast `a `, `ion`, `ios`, words containing Z, deliberate modifiers, all thumb layers, `Fun+;`, and `Fun+/`.
Check both release orders for Fun and confirm that no keys or modifiers remain held.
Do not call the hardware fix complete until these checks pass.

## Hammerspoon

`init.lua` loads `miryoku_cheatsheet.lua`, which shows the active layer with
the physical Piantor keys and highlights held modifiers. It reads
`miryoku_layers.json` for labels and runs `vial_matrix_monitor.py` over raw
HID to detect layer holds.

The monitor needs a Python venv with `hidapi`:

```sh
uv venv ~/.hammerspoon/vial-hid-venv
uv pip install --python ~/.hammerspoon/vial-hid-venv/bin/python -r ~/dotfiles/keyboard/hammerspoon/requirements.txt
```

Pause the monitor before using Vial: `Ctrl+Alt+Cmd+V` toggles it. It also
pauses on its own while a Vial Web tab is open in Chrome.

## Karabiner

`karabiner.json` is the full config. Rules used by this setup:

- Built-in `fn` sends F19 (Scribe push-to-talk). The Piantor sends F19 from
  `Fun + /`.
- Piantor F1-F12 act as plain function keys.
- Caps Lock is Cmd on hold, F18 on tap.
- The Miryoku home row and layer rules for the MacBook keyboard live in
  `miryoku-qwerty.json` and are disabled by default.

## Key chords

| Chord | Result |
|---|---|
| `Fun + ;` | Lock screen (Ctrl+Cmd+Q) |
| `Fun + /` | F19, Scribe |
| `Fun + Space` | Raycast (Cmd+Space) |
| `Z` hold | Number layer, left hand types digits |
| `Mouse + R` / `Mouse + S` | Slow / fast pointer |

Fun+Space sends Cmd+Space directly. Normal A and Space keep their typing protection.
The popup labels this shortcut `Launcher`.
