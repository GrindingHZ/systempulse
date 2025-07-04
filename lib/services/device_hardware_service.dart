import 'package:cpu_memory_tracking_app/models/device_hardware_info.dart';

class DeviceHardwareService {
  static final DeviceHardwareService _instance = DeviceHardwareService._internal();
  factory DeviceHardwareService() => _instance;
  DeviceHardwareService._internal();

  DeviceHardwareInfo? _cachedHardwareInfo;

  /// Get device hardware information (cached after first call)
  Future<DeviceHardwareInfo> getDeviceHardwareInfo() async {
    _cachedHardwareInfo ??= await DeviceHardwareInfo.getDeviceHardwareInfo();
    return _cachedHardwareInfo!;
  }

  /// Force refresh device hardware information
  Future<DeviceHardwareInfo> refreshDeviceHardwareInfo() async {
    _cachedHardwareInfo = await DeviceHardwareInfo.getDeviceHardwareInfo();
    return _cachedHardwareInfo!;
  }

  /// Check if hardware info is available
  bool get hasHardwareInfo => _cachedHardwareInfo != null;

  /// Get cached hardware info (returns null if not loaded)
  DeviceHardwareInfo? get cachedHardwareInfo => _cachedHardwareInfo;
}
