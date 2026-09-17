/// Hardware facts read from the device.
///
/// Every field is nullable and every null means "this device did not report it". Nothing here is
/// inferred. The implementation this replaces guessed: any 8-core Android device was presented to
/// its owner as a "MediaTek Dimensity 8300-Ultra @ 3.35 GHz with 8.0 GB", regardless of what the
/// hardware actually was. A blank row is honest; a plausible invented one is not.
class DeviceProfile {
  const DeviceProfile({
    this.model,
    this.manufacturer,
    this.board,
    this.hardware,
    this.androidRelease,
    this.sdkInt,
    this.abis = const [],
    this.coreCount,
    this.maxCpuFrequencyMhz,
    this.totalRamBytes,
    this.screenWidthPx,
    this.screenHeightPx,
    this.screenDensityDpi,
  });

  final String? model;
  final String? manufacturer;
  final String? board;
  final String? hardware;
  final String? androidRelease;
  final int? sdkInt;
  final List<String> abis;
  final int? coreCount;

  /// Peak clock from cpufreq sysfs, or null where the kernel does not expose it to apps.
  final int? maxCpuFrequencyMhz;

  final int? totalRamBytes;
  final int? screenWidthPx;
  final int? screenHeightPx;
  final int? screenDensityDpi;

  /// Manufacturer and model as one line, e.g. "Google Pixel 8". Null if neither is known.
  String? get displayName {
    final parts = [manufacturer, model].whereType<String>().where((s) => s.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// The ABI the app is actually running as, which is the first entry Android reports.
  String? get primaryAbi => abis.isEmpty ? null : abis.first;

  factory DeviceProfile.fromMap(Map<dynamic, dynamic> map) {
    String? str(String key) {
      final value = map[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    int? integer(String key) {
      final value = map[key];
      return value is num ? value.toInt() : null;
    }

    return DeviceProfile(
      model: str('deviceModel'),
      manufacturer: str('manufacturer'),
      board: str('board'),
      hardware: str('hardware'),
      androidRelease: str('androidRelease'),
      sdkInt: integer('sdkInt'),
      abis: (map['abis'] as List?)?.whereType<String>().toList() ?? const [],
      coreCount: integer('coreCount'),
      maxCpuFrequencyMhz: integer('maxCpuFrequencyMhz'),
      totalRamBytes: integer('totalRamBytes'),
      screenWidthPx: integer('screenWidthPx'),
      screenHeightPx: integer('screenHeightPx'),
      screenDensityDpi: integer('screenDensityDpi'),
    );
  }
}
