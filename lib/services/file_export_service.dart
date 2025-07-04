import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:cpu_memory_tracking_app/models/recording_session.dart';
import 'package:cpu_memory_tracking_app/models/performance_data.dart';

class FileExportService {
  static final FileExportService _instance = FileExportService._internal();
  factory FileExportService() => _instance;
  FileExportService._internal();

  /// Export session to CSV and save to Downloads folder
  Future<ExportResult> exportToDownloads(RecordingSession session) async {
    try {
      print('📁 Starting CSV export to Downloads folder...');
      
      // Request storage permissions
      final hasPermission = await _requestStoragePermissions();
      if (!hasPermission) {
        print('❌ Storage permission denied');
        return ExportResult.error('Storage permission denied');
      }
      print('✅ Storage permissions granted');

      // Get Downloads directory with multiple fallback strategies
      Directory downloadsDir;
      
      if (Platform.isAndroid) {
        // Strategy 1: Try public Downloads folder (most reliable for Android 11+)
        final publicDownloads = Directory('/storage/emulated/0/Download');
        if (await publicDownloads.exists()) {
          downloadsDir = publicDownloads;
          print('✅ Using public Downloads: ${publicDownloads.path}');
        } else {
          print('⚠️ Public Downloads not accessible, trying alternatives...');
          
          // Strategy 2: Try external storage Downloads
          Directory? altDownloads;
          try {
            final List<Directory>? externalDirs = await getExternalStorageDirectories();
            if (externalDirs != null && externalDirs.isNotEmpty) {
              // Navigate to Downloads folder
              final String externalPath = externalDirs.first.path.split('/Android')[0];
              final testDir = Directory('$externalPath/Download');
              
              if (await testDir.exists()) {
                altDownloads = testDir;
                print('✅ Using external Downloads: ${testDir.path}');
              }
            }
          } catch (e) {
            print('⚠️ External storage access failed: $e');
          }
          
          // Strategy 3: Fallback to app documents directory
          if (altDownloads != null) {
            downloadsDir = altDownloads;
          } else {
            downloadsDir = await getApplicationDocumentsDirectory();
            print('⚠️ Fallback to app directory: ${downloadsDir.path}');
          }
        }
      } else {
        // For other platforms, use Documents directory
        downloadsDir = await getApplicationDocumentsDirectory();
        print('✅ Using Documents directory: ${downloadsDir.path}');
      }

      if (!await downloadsDir.exists()) {
        print('❌ Could not access storage directory: ${downloadsDir.path}');
        return ExportResult.error('Could not access Downloads folder');
      }

      // Generate filename with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'SystemPulse_${session.id}_$timestamp.csv';
      final file = File('${downloadsDir.path}/$fileName');
      
      print('📄 Creating file: ${file.path}');

      // Generate CSV content
      final csvContent = _generateCsvContent(session);
      
      // Write file
      await file.writeAsString(csvContent);
      
      // Verify file was created successfully
      if (await file.exists()) {
        final fileSize = await file.length();
        print('✅ File created successfully: ${file.path} ($fileSize bytes)');
        return ExportResult.success(file.path);
      } else {
        print('❌ File creation failed');
        return ExportResult.error('Failed to create file');
      }
    } catch (e) {
      print('❌ Export error: $e');
      return ExportResult.error('Export failed: $e');
    }
  }

  /// Export session to temporary location and share
  Future<ShareResult> shareSession(RecordingSession session, {Rect? sharePositionOrigin}) async {
    try {
      // Create temporary file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'SystemPulse_${session.id}_$timestamp.csv';
      final tempFile = File('${tempDir.path}/$fileName');

      // Generate CSV content
      final csvContent = _generateCsvContent(session);
      
      // Write to temporary file
      await tempFile.writeAsString(csvContent);

      // Share the file
      final result = await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'SystemPulse performance data from ${_formatDateTime(session.startTime)}',
        subject: 'Performance Monitoring Data - ${session.id}',
        sharePositionOrigin: sharePositionOrigin,
      );

      return ShareResult.success(result);
    } catch (e) {
      return ShareResult.error('Share failed: $e');
    }
  }

  /// Export and show options dialog
  Future<void> showExportDialog(BuildContext context, RecordingSession session) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Export Recording'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Export recording from ${_formatDateTime(session.startTime)}'),
              const SizedBox(height: 8),
              Text(
                '${session.dataPoints.length} data points • ${_formatDuration(session.duration)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await _handleDownload(context, session);
              },
              icon: const Icon(Icons.download),
              label: const Text('Download'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await _handleShare(context, session);
              },
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ],
        );
      },
    );
  }

  /// Handle download to Downloads folder
  Future<void> _handleDownload(BuildContext context, RecordingSession session) async {
    try {
      // Show loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Exporting to Downloads...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final result = await exportToDownloads(session);

      if (context.mounted) {
        if (result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('✅ Export successful!'),
                  Text(
                    'Saved to: ${result.filePath!.split('/').last}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Share',
                textColor: Colors.white,
                onPressed: () => _handleShare(context, session),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle sharing via apps
  Future<void> _handleShare(BuildContext context, RecordingSession session) async {
    try {
      final result = await shareSession(session);
      
      if (!result.isSuccess && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Share failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Request storage permissions
  Future<bool> _requestStoragePermissions() async {
    if (Platform.isAndroid) {
      print('🔑 Requesting Android storage permissions...');
      
      // For Android 11+ (API 30+), we need different permissions
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      print('📱 Android SDK: ${androidInfo.version.sdkInt}');
      
      if (androidInfo.version.sdkInt >= 30) {
        // Android 11+ - Request manage external storage first
        print('🔐 Requesting MANAGE_EXTERNAL_STORAGE for Android 11+...');
        var status = await Permission.manageExternalStorage.status;
        
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
          print('📋 MANAGE_EXTERNAL_STORAGE result: $status');
        }
        
        if (status.isGranted) {
          print('✅ MANAGE_EXTERNAL_STORAGE granted');
          return true;
        }
        
        if (status.isPermanentlyDenied) {
          print('❌ MANAGE_EXTERNAL_STORAGE permanently denied');
          // Still try regular storage permission as fallback
        }
        
        // Fallback to regular storage permission
        print('🔐 Fallback to regular storage permissions...');
        final storageStatus = await Permission.storage.request();
        print('📋 Storage permission result: $storageStatus');
        return storageStatus.isGranted;
      } else {
        // Android 10 and below
        print('🔐 Requesting storage permissions for Android 10 and below...');
        final status = await Permission.storage.request();
        print('📋 Storage permission result: $status');
        return status.isGranted;
      }
    }
    print('✅ Non-Android platform, no permissions needed');
    return true; // iOS and other platforms don't need explicit permission
  }

  /// Generate CSV content from session
  String _generateCsvContent(RecordingSession session) {
    List<List<String>> csvData = [];
    
    // Add headers with metadata
    csvData.add(['# SystemPulse Performance Data']);
    csvData.add(['# Session ID', session.id]);
    csvData.add(['# Start Time', session.startTime.toIso8601String()]);
    csvData.add(['# End Time', session.endTime?.toIso8601String() ?? 'Ongoing']);
    csvData.add(['# Duration', _formatDuration(session.duration)]);
    csvData.add(['# Data Points', session.dataPoints.length.toString()]);
    csvData.add(['# Average CPU', '${session.averageCpuUsage.toStringAsFixed(2)}%']);
    csvData.add(['# Average Memory', '${session.averageMemoryUsage.toStringAsFixed(2)}%']);
    csvData.add(['# Max CPU', '${session.maxCpuUsage.toStringAsFixed(2)}%']);
    csvData.add(['# Max Memory', '${session.maxMemoryUsage.toStringAsFixed(2)}%']);
    csvData.add(['']); // Empty row
    
    // Add data headers
    csvData.add(PerformanceData.csvHeaders);
    
    // Add data points
    for (final dataPoint in session.dataPoints) {
      csvData.add(dataPoint.toCsvRow());
    }

    return const ListToCsvConverter().convert(csvData);
  }

  /// Format DateTime for display
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Format Duration for display
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}

/// Result class for export operations
class ExportResult {
  final bool isSuccess;
  final String? filePath;
  final String? error;

  ExportResult.success(this.filePath) : isSuccess = true, error = null;
  ExportResult.error(this.error) : isSuccess = false, filePath = null;
}

/// Result class for share operations
class ShareResult {
  final bool isSuccess;
  final Object? result;
  final String? error;

  ShareResult.success(this.result) : isSuccess = true, error = null;
  ShareResult.error(this.error) : isSuccess = false, result = null;
}
