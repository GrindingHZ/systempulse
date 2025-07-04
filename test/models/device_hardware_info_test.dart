import 'package:flutter_test/flutter_test.dart';
import 'package:cpu_memory_tracking_app/models/device_hardware_info.dart';

void main() {
  group('DeviceHardwareInfo Tests', () {
    test('should create DeviceHardwareInfo with all fields', () {
      final hardwareInfo = DeviceHardwareInfo(
        processorName: 'Test Processor',
        coreCount: 8,
        clockSpeed: '3.2 GHz',
        totalRamGB: '8 GB',
        ramType: 'DDR4',
        architecture: 'x64',
        deviceModel: 'Test Model',
        osVersion: '1.0.0',
      );

      expect(hardwareInfo.processorName, equals('Test Processor'));
      expect(hardwareInfo.coreCount, equals(8));
      expect(hardwareInfo.clockSpeed, equals('3.2 GHz'));
      expect(hardwareInfo.totalRamGB, equals('8 GB'));
      expect(hardwareInfo.ramType, equals('DDR4'));
      expect(hardwareInfo.architecture, equals('x64'));
      expect(hardwareInfo.deviceModel, equals('Test Model'));
      expect(hardwareInfo.osVersion, equals('1.0.0'));
    });

    test('should handle null clock speed', () {
      final hardwareInfo = DeviceHardwareInfo(
        processorName: 'Test CPU',
        coreCount: 4,
        clockSpeed: null,
        totalRamGB: '4 GB',
        ramType: 'Not Available',
        architecture: 'x86',
        deviceModel: 'Test Device',
        osVersion: '1.0',
      );

      expect(hardwareInfo.clockSpeed, isNull);
      expect(hardwareInfo.coreCount, equals(4));
      expect(hardwareInfo.processorName, equals('Test CPU'));
    });

    test('should handle empty string values', () {
      final hardwareInfo = DeviceHardwareInfo(
        processorName: '',
        coreCount: 0,
        clockSpeed: '',
        totalRamGB: '',
        ramType: '',
        architecture: '',
        deviceModel: '',
        osVersion: '',
      );

      expect(hardwareInfo.processorName, equals(''));
      expect(hardwareInfo.coreCount, equals(0));
      expect(hardwareInfo.totalRamGB, equals(''));
      expect(hardwareInfo.deviceModel, equals(''));
    });

    test('should handle high core count values', () {
      final hardwareInfo = DeviceHardwareInfo(
        processorName: 'High-end CPU',
        coreCount: 128,
        clockSpeed: '5.0 GHz',
        totalRamGB: '128 GB',
        ramType: 'DDR5',
        architecture: 'x64',
        deviceModel: 'Workstation',
        osVersion: '3.0',
      );

      expect(hardwareInfo.coreCount, equals(128));
      expect(hardwareInfo.totalRamGB, equals('128 GB'));
      expect(hardwareInfo.processorName, equals('High-end CPU'));
    });

    test('should preserve special characters in string fields', () {
      final hardwareInfo = DeviceHardwareInfo(
        processorName: 'CPU with (special) characters!',
        coreCount: 8,
        clockSpeed: '3.2 GHz',
        totalRamGB: '8 GB',
        ramType: 'DDR4-3200',
        architecture: 'x86_64',
        deviceModel: 'Model-with-dashes_and_underscores',
        osVersion: 'Version 1.2.3-beta',
      );

      expect(hardwareInfo.processorName, equals('CPU with (special) characters!'));
      expect(hardwareInfo.ramType, equals('DDR4-3200'));
      expect(hardwareInfo.deviceModel, equals('Model-with-dashes_and_underscores'));
      expect(hardwareInfo.osVersion, equals('Version 1.2.3-beta'));
    });

    test('should handle typical Android device configuration', () {
      final hardwareInfo = DeviceHardwareInfo(
        processorName: 'Snapdragon 8 Gen 2',
        coreCount: 8,
        clockSpeed: '3.2 GHz',
        totalRamGB: '12 GB',
        ramType: 'LPDDR5',
        architecture: 'arm64-v8a',
        deviceModel: 'Samsung Galaxy S23',
        osVersion: 'Android 13 (API 33)',
      );

      expect(hardwareInfo.processorName, equals('Snapdragon 8 Gen 2'));
      expect(hardwareInfo.coreCount, equals(8));
      expect(hardwareInfo.architecture, equals('arm64-v8a'));
      expect(hardwareInfo.totalRamGB, equals('12 GB'));
    });

    test('should handle typical iOS device configuration', () {
      final hardwareInfo = DeviceHardwareInfo(
        processorName: 'Apple A17 Pro',
        coreCount: 6,
        clockSpeed: 'Not Available',
        totalRamGB: '8 GB',
        ramType: 'Not Available',
        architecture: 'arm64',
        deviceModel: 'iPhone 15 Pro',
        osVersion: 'iOS 17.0',
      );

      expect(hardwareInfo.processorName, equals('Apple A17 Pro'));
      expect(hardwareInfo.coreCount, equals(6));
      expect(hardwareInfo.deviceModel, equals('iPhone 15 Pro'));
      expect(hardwareInfo.osVersion, equals('iOS 17.0'));
    });
  });
}
