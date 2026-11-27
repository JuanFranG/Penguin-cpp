# Manual window captures (macOS)

Build `manualcapture.lpi` with the same Lazarus/FPC Cocoa toolchain as the IDE. This documentation utility is not part of the production executable. The main project must have generated `Source/penguin-cpp.res` first.

Run from the repository root, with `PENGUIN_MANUAL_WORK` pointing to a disposable, private folder and `PENGUIN_MANUAL_OUTPUT` to `Manual/assets/windows`. Do not use a folder containing personal work. The helper creates `config.ini`, `main.cpp`, `Tutorial.dev` and profiling output in the work folder.

The fixture uses English and a light application palette. Captures use the native `screencapture` utility because Cocoa's `GetFormImage` omits some native controls. macOS must allow screen capture. It reads the released `/Applications/Penguin cpp.app` resource directory to illustrate its included Windows environment and can find its bundled astyle when that app's `Contents/MacOS` is on PATH.

The helper opens actual forms without saving settings to the user's normal configuration. It does not exercise every feature shown in the images. Read `Manual/assets/README.md` for capture limits. Update the editable `Manual/windows.json`, then run `python3 packaging/build-manual.py` to refresh the HTML reference.

After building, capture both the form reference and the main application views:

```sh
# Run from the repository root. Use a new disposable directory.
export PENGUIN_MANUAL_WORK="$(mktemp -d /tmp/penguin-manual.XXXXXX)"
export PENGUIN_MANUAL_OUTPUT="$PWD/Manual/assets/windows"
export PATH="/Applications/Penguin cpp.app/Contents/MacOS:$PATH"
Source/Tools/ManualCapture/build/manualcapture
python3 Source/Tools/ManualCapture/capture-main.py "$PENGUIN_MANUAL_WORK"
python3 packaging/build-manual.py
python3 packaging/check-manual.py
```

`capture-main.py` must run last: it replaces the helper's welcome/editor images with captures of the released executable, whose custom tab strips are fully initialised. It starts and closes only its own process. Its separate preferences and sample project are written to a temporary directory. Neither tool saves to the normal user configuration.

The first-use setup screenshots run a real Windows compiler/runtime smoke test against a **private disposable prefix** below the work directory. Keep the included runtime available and allow time for prefix creation. These tools require macOS screen capture permissions; the main capture also uses System Events to bring its own window forward. They are not run by Linux CI. The checked-in images let CI validate the manual without screen access or a GUI.
