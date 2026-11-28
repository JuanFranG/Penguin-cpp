# Screenshot provenance

The window reference documents Penguin cpp **0.5.6 and subsequent, unreleased interface fixes**, with its interface in **English**, on macOS / Cocoa. These are native window captures, not mockups or AI-generated images. macOS window frames are included; its global menu bar is outside the captured window.

`windows/captures.tsv` records view name, form class, caption and PNG dimensions. The capture utility is `Source/Tools/ManualCapture/`. It opens the real application forms with disposable preferences and a small `Tutorial` project, then uses the native window capture API. No private projects or recent-file lists are used. The welcome/editor/header views are captured from an isolated instance of the released application using the same sample files. The refreshed dialogs, debugger and CPU views use the patched source; these fixes are not yet in the public 0.5.6 installers.

The preparation/ready screenshots run the included Windows compiler and runtime against a disposable private environment. The profiler screenshot uses actual LLVM-instrumented output from the sample program. The original CPU view is idle. The additional debugger/CPU views are an actual LLDB session stopped in calculator.cpp: left=2, right=3 and total=5, with real registers, instructions and call frames. ClangFormat is optional and was unavailable in this environment; its view must not be read as a verified live formatter preview. The update dialog shows the real published release check at capture time. Linux window decoration and platform-specific controls can differ.

The legacy icon-library form could not be constructed (`IconView.Items.ItemData` is not recognised by the Lazarus list view); no image has been invented for it. Open/Save and native printer dialogs are OS-provided and not represented as a fixed cross-platform UI.

Images are part of the Penguin cpp documentation, under the repository's licence. `penguin.png`, `Heebo.ttf` and `OFL.txt` are copied from the existing website assets; the font retains its SIL Open Font License notice. See `packaging/site/assets/README.md` for their upstream provenance.
