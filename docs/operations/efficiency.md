# Efficiency: Google Play vitals and battery (2026-10-21)

Google Play watches every app's **vitals**: crashes, "app not responding" (ANR), slow
start, slow frames, battery drain (wake locks, wake-ups, background work), and size. Bad
vitals push an app down the store. Many of our members use cheap phones with little data, so
we care about these numbers twice over.

## Where the app stands

- **No background work.** There are no timers, polling, services, wake locks or background
  location. The app wakes the radio only when the member opens a screen or pulls to
  refresh, so it costs nothing while closed.
- **Paused animations on hidden tabs.** Home keeps its tabs alive in an `IndexedStack`, so
  switching back is instant. Each tab is wrapped in `TickerMode(enabled: i == _tab)`, so a
  spinning loader or a pulsing tour hint on a hidden tab stops drawing frames. Before, a
  hidden tab's loader kept the screen redrawing and the battery working.
- **Tabs built on first visit.** A tab is built only when first opened, not at start.
- **Heavy checks off the main thread.** Checking the hash chain, and now also members'
  countersignatures (`countersignCheckProvider` in `records_tab.dart`), runs on a
  background isolate through `chainRunnerProvider`. Hundreds of ECDSA checks on the UI
  thread would freeze the screen (jank, and an ANR on slow phones). An empty list is checked
  in place, with no isolate started.
- **Compressed downloads.** The API now gzips answers (about 4x smaller), and Dart's HTTP
  client accepts gzip by default.

## Measured on a real phone (2026-10-21)

Samsung Galaxy S23 Ultra, Android 16, arm64 release build against the test server, Impeller
on Vulkan.

| What | Result | Google's line |
|---|---|---|
| Cold start (5 runs) | 0.24-0.53 s | slow at 5 s or more |
| Return to the app (hot start) | 0.06-0.10 s | slow at 1.5 s or more |
| Scrolling Overview (338 frames) | 0 janky, 0 dropped | |
| Scrolling Records, with the chain check (560 frames) | 0 janky, 0 dropped | |
| Sitting on a screen, untouched, 15 s | 0 frames drawn | |
| In the background, 60 s | 0 CPU time, no alarms, jobs, services or wake locks | |
| Download size for this phone | 27.8 MB | |

Frames were read with `dumpsys SurfaceFlinger --timestats` (the `--latency` dump is empty for
Flutter's surface on Android 16). Background CPU is `/proc/<pid>/stat` fields 14+15, read a
minute apart. A flagship phone is the easy case. Repeat on a cheap phone (2-3 GB RAM) before
launch.

## Measured on the emulator

- **Cold start** on the emulator, software rendering (slower than a real phone): 2.7-3.0 s
  from tap to first frame. Google calls 5 s or more slow.
- Three cold starts, no crash, with Impeller (OpenGLES).
- **Emulator note:** with `-gpu host` on this PC the emulator's graphics driver reports a
  maximum texture size of 0, and Impeller aborts at start ("Requested texture size (1, 1)
  exceeds maximum supported size of (0, 0)"). That is the emulator's host GPU, not the app.
  Run the emulator with `-gpu swiftshader_indirect -feature -Vulkan` to test. Watch Play
  Console's crash list after the first release in case some real phone's driver does the
  same. The fix would then be the manifest switch
  `io.flutter.embedding.android.EnableImpeller=false` for those devices.

## Size

The universal release APK is about 80 MB because it carries three processor types. One phone
needs about 30 MB: the Flutter engine about 12 MB, our code about 10 MB, and the bundled
barcode scanner (ML Kit) about 5 MB. We keep the scanner bundled, because many Huawei phones
in Kenya have no Google Play services to download it.

`tool/build_release.sh <api-url> <platform-key-fingerprint>` builds what goes to Play:

- an **app bundle** (`.aab`), so each phone downloads only its own processor's code;
- `--obfuscate --split-debug-info=build/symbols`, which strips Dart symbols (smaller and
  harder to read). Keep `build/symbols` for every release: `flutter symbolize` needs it to
  read crash stack traces from Play Console.
