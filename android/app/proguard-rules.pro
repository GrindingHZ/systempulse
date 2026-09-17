# Flutter's embedding references these reflectively; R8 cannot see the reference and would strip
# them, which surfaces at runtime rather than build time.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }

# Entry points reached from the manifest or from Dart via MethodChannel rather than from Kotlin
# call sites, so R8 has no static reference to keep them alive.
-keep class com.systempulse.monitor.MainActivity { *; }
-keep class com.systempulse.monitor.recording.RecordingService { *; }

# Keep source file and line numbers so release crash reports stay readable, but rename the
# attribute so the original file names are not shipped.
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable
