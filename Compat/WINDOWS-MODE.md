# Windows compatibility integration

Published experimental 0.5.0 profile, 13 November 2026. Complete PKG/DMG and corresponding sources are release assets; see [redistribution report](REDISTRIBUTION.md).

## User flow

The macOS 26+ Apple Silicon package can include Penguin, LLVM-MinGW 20261104,
GNU Make 4.4.1 and the curated MetalSharp Wine 6.5 ARM64/FEX runtime. Versions
and input hashes are checked by the packaging scripts. First launch creates a
private environment under the user's application data and compiles/runs the
bundled self-test, with progress, cancellation, retry and a diagnostic log.
An incomplete default prefix is backed up before recovery; its server is stopped
before moving it. A fresh server must persist its registry before readiness is
cached. Custom folders are not automatically moved. Setup failures show a
copyable diagnostic, and failed settings commits preserve the previous file.
Nothing is downloaded or installed into a Wine prefix by the package's root scripts.

Automatic is the default compatibility mode. Compiled source files and recursively
included local headers are scanned for Windows dependencies. If Apple developer
tools are unavailable, the bundled Windows compiler is also the fallback.
Tools > Windows compatibility offers Automatic / Native / Windows and advanced
paths. Explicit project settings and legacy opt-outs are preserved. Standalone
source files use the global selection. Computed preprocessor includes are not
fully resolved by this heuristic; use explicit Windows mode for ambiguous cases.

Compile and Compile & Run save/build the Windows executable using bundled Make.
Console output uses Penguin's terminal launcher; GUI projects run directly.
Development changes after 0.5.0 add Unicode/UTF-8 (default), OEM 437, ANSI 1252
and program-controlled console profiles. Recompile after changing the profile;
DOS box bytes such as 218/196/191 need OEM 437. The MIT-licensed
`windows/console-startup.c` aligns CRT LC_CTYPE and console code pages without
changing numeric formatting. Explicit program settings take precedence. The
launcher restores Unix keyboard mode and terminal style on exit. Program-controlled
mode links no startup object. These changes do not update the published packages;
see [stage 3/4 validation and limits](../QA_STAGES_3_4.md).

Development stage 5 explicitly rejects active `.rc`/`.res` inputs in generated
builds, including resource files listed as extra linker inputs. Windows builds
also reject requested private resources, icons, version information and XP
manifests because that pipeline is not implemented. Native builds preserve this
metadata and warn that it is not applied. A native custom Makefile may implement
its own resource pipeline. See [stage 5](../QA_STAGE_5.md).

Objects use `.win.o`, and native compiler include/library/SDK flags are isolated.
The prefix is private to the user, shared by compatible projects, and survives
application updates. Changing the environment invalidates its readiness cache.
Native macOS compilation and debugging still require Apple's developer tools.

## Evidence

- Cocoa default build on ARM64; configuration, source detection, PE recognition,
  argument boundaries, prefix rejection and legacy settings tests pass.
- First-launch setup and project Compile & Run were exercised in an isolated IDE
  configuration with no selected Apple developer directory. The resulting Windows
  program wrote its expected Win32/math marker. This simulates missing developer
  tools; it is not a clean physical Mac installation test.
- The curated runtime passes `windows.h`, `conio.h`, math/stdlib/STL and memory GDI
  operations in the packaged self-test. A fresh prefix may emit a Wine
  `virtual_alloc_first_teb` assertion from a startup child even when the probe
  exits successfully; retain `Compatibility/windows/setup.log` for diagnosis.
- 9,824 form resource checks across 37 resource forms pass. This is structural
  validation, not a visual review of every translation and resolution.
- Toolbar painting on current AppKit is corrected by clipping LCL custom views.
  Compiler/class/member selectors adapt to the window width; observed at 1440
  and 1000 logical points without overlap.

## Runtime curation and limitations

`packaging/prepare-windows-runtime.py` verifies the pinned upstream archive,
curates a separate copy and records file hashes. The reviewed copy has 169 thin
ARM64 host Mach-O files and no Intel-only host binaries. Windows x64 PE files
are intentional guests for FEX. Original third-party files are retained unchanged.
The IDE supplies the GStreamer/Vulkan environment formerly set by the wrapper.

Excluded paths include Microsoft redistributable/font installers and shader SDK
payloads, FMOD and Intel shims, Apple's Metal Shader Converter, Mono and Gecko.
The optional unlicensed `lib/linuxhost` is also excluded; its Linux-module
anticheat support is not supplied.
No proprietary installer or Apple agreement is accepted by this flow. The base
package does not use GPTK; its legacy advanced checkbox installs nothing.

This does not promise complete Windows API or game compatibility. In particular,
`graphics.h`/WinBGIm and arbitrary third-party libraries are not supplied by MinGW
or Wine. The separate native SDL/Metal prototype exposes a limited API and is not
automatically linked in this Windows target. Native Windows debugging/profiling
and code completion using the Windows SDK are not implemented.

The pinned profile ships corresponding sources, patches, build recipes and
notices in `Penguin-cpp-0.5.0-COMPAT-SOURCES.tar.gz`. The public packaging gate
checks that archive against the reviewed lock. Developer ID signing/notarization
and real installation/update/failure recovery on a clean Mac and macOS 26
remain pending. Future macOS 28 support is not demonstrated by today's
ARM64 execution. Linux package metadata uses APT MinGW/Wine dependencies on amd64;
that is not evidence of a full installation/runtime test on Linux.

Pinned runtime archive: https://github.com/metalsharp/MetalSharp-Wine/releases/tag/v6.5
SHA256: `574199696623371d6c4abfe5d242c86403cc4ba4b4b5643f5e6187a6d5b86d4b`.
