# SystemPulse - CPU & Memory Monitor

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

A Flutter application for monitoring real-time CPU and memory usage on Android devices. Track performance metrics, record sessions, and export data to CSV files.

## Features

- **Real-time Monitoring**: Live CPU and memory usage with animated gauges
- **Recording Sessions**: Start/stop recording with background data collection
- **Smart Notifications**: Live updates during recording with stop button
- **Interactive Charts**: Zoomable charts with performance data visualization
- **CSV Export**: Export session data to CSV files with sharing options
- **Device Information**: View complete hardware and system specifications
- **Session History**: Manage and view all recorded sessions
- **Theme Support**: Light, dark, and system theme options
- **Settings**: Configure recording intervals and notification preferences

## Screenshots

[Add screenshots of your app here]

## Requirements

- Android 5.0 (API level 21) or higher
- Flutter 3.8.1 or higher (for development)

## Installation

### For Users
1. Download the APK from the releases section
2. Install on your Android device
3. Grant necessary permissions when prompted

### For Developers
1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd cpu_memory_tracking_app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## How to Use

1. **Start Monitoring**: Open the app to see real-time CPU and memory usage
2. **Record Sessions**: Tap the record button to start collecting data
3. **View Notifications**: Check the notification bar for live updates during recording
4. **Stop Recording**: Use the stop button in the notification or app
5. **Export Data**: Access session history and export to CSV files
6. **Device Info**: View your device specifications in the info section

## Permissions

- **Storage**: To save CSV files
- **Notifications**: To display recording status and controls

## Technical Details

- **Platform**: Android (Flutter framework)
- **Architecture**: Provider pattern for state management
- **Data Storage**: Local storage with SharedPreferences
- **Charts**: FL Chart library for data visualization
- **Native Code**: Kotlin for Android-specific performance monitoring

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License.

---

**Built with Flutter for Android**
