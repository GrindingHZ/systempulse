# SystemPulse

Measures how much CPU this app's own process uses, how much memory the device has in use, and what
the battery is doing — live, or recorded to a file you can export as CSV.

Android is the supported platform. A Linux desktop preview build exists for working on the
interface without a device.

## What the numbers mean

Precision about definitions matters more here than in most apps, because "CPU usage" on a
multi-core, frequency-scaling device can mean several different things.

| Reading | Definition |
| --- | --- |
| **App CPU** | This process's CPU time (user + system, all threads) divided by elapsed wall-clock time and core count. One fully busy thread on an 8-core device reads 12.5%. |
| **CPU, one core** | The same measurement against a single core, so 100% is one core saturated and 400% is four. |
| **Device memory** | `totalMem − availMem` for the whole device. Linux counts reclaimable page cache as used, so a healthy device reads high. This is *not* a pressure signal — "Memory pressure" is. |
| **App memory** | This process's proportional set size: its private memory plus its share of anything mapped by several processes. |
| **Battery** | Level, temperature and charge state from the system's battery broadcast. |

A metric the device will not report shows as **—**, and exports leave that field empty. Nothing is
estimated, substituted or interpolated.

### How App CPU is measured

`/proc/self/stat` is sampled on a fixed interval and the difference between consecutive readings is
divided by the elapsed time:

```
utilisation = (cpuTimeNow − cpuTimeBefore) / (wallClockNow − wallClockBefore) / coreCount
```

This is the same definition `top` uses. A process's own `/proc` entry is always readable regardless
of SELinux policy, and `android.os.Process.getElapsedCpuTime()` is the fallback if parsing fails.

> **Note for anyone holding older exports from this app.** Before this rewrite, the column labelled
> CPU usage was not utilisation at all: it averaged `scaling_cur_freq / cpuinfo_max_freq` across
> cores — the clock-speed ratio, read from global sysfs rather than from this process. An idle
> device reported a large non-zero figure because idle cores park at their minimum frequency, a
> throttled but fully busy process reported *less* than an idle one, and on devices where sysfs is
> restricted it silently reported exactly `0.00`. **CSV files produced before this change are not
> comparable with ones produced after it, and the old values should not be treated as CPU usage.**

## Recording

Recording runs in an Android foreground service, so it continues while the app is in the background.
Each sample is appended to disk as it is taken, which bounds the loss from an unexpected process
death to a few seconds rather than the whole session. If the app is killed mid-recording, the
session is closed out at its last recorded sample on next launch and marked **Recovered**.

Storage layout, under the app's private files directory:

```
sessions/<id>.json     session header: timestamps, sample count, interval
sessions/<id>.jsonl    append-only sample stream, one JSON object per line
```

Timestamps are stored and exported in UTC and shown in local time.

## Exporting

Export writes RFC 4180 CSV into the system Downloads collection through MediaStore, which requires
no storage permission on Android 10 and later. `MANAGE_EXTERNAL_STORAGE` is deliberately not
requested: it grants access to the entire shared volume and Google Play does not accept it for an
app of this kind.

## Permissions

| Permission | Why |
| --- | --- |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE` | Keep sampling while the app is backgrounded during a recording the user started. |
| `POST_NOTIFICATIONS` | Show the ongoing recording notification. Requested when a recording starts; denying it does not stop the recording. |
| `WRITE_EXTERNAL_STORAGE` (API ≤ 28 only) | Exporting on releases predating scoped storage. |

## Building

```bash
flutter pub get
flutter run                       # debug, on a connected Android device
flutter build apk --release
```

### Release signing

Release builds read `android/key.properties`, which is git-ignored. Copy
`android/key.properties.example` and fill it in:

```bash
keytool -genkey -v -keystore android/upload-keystore.jks \
        -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Without that file the release build still completes but is signed with the **debug** key and prints
a warning. Google Play rejects debug-signed uploads.

### Previewing the interface without a device

```bash
flutter run -d linux -t lib/dev/preview_main.dart
```

`lib/dev/` supplies scripted telemetry through the same `MetricsSource` interface the real app uses.
It is not referenced from `main.dart`, so it never reaches a release build.

## Tests

```bash
flutter test --exclude-tags golden          # unit and controller tests
flutter test --tags golden                  # render the screens and compare to committed images
flutter test --tags golden --update-goldens # after an intentional UI change
cd android && ./gradlew :app:testDebugUnitTest
```

The Kotlin tests cover the `/proc/self/stat` parser — including process names containing spaces and
parentheses, which break naive whitespace splitting — and the utilisation arithmetic.

## Layout

```
lib/
  design/      tokens, iOS type scale, and the components built from them
  data/        models, the platform channel, file-backed storage, CSV export
  state/       MonitorController: sampling, recording lifecycle, settings
  features/    one file per screen
  dev/         scripted telemetry for the preview build
android/app/src/main/kotlin/com/systempulse/monitor/
  metrics/     CPU, memory, battery and device-info sampling
  recording/   the foreground service and its append-only sample writer
  export/      MediaStore writer
```
