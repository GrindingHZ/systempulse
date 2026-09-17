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

# Flutter's embedding contains PlayStoreDeferredComponentManager, which references the Play Core
# library. Play Core is only a dependency of apps that use deferred components / split installs.
# This app does not, so those classes are absent and R8 fails the build outright:
#
#   Missing class com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
#   (referenced from: io.flutter.embedding.engine.deferredcomponents.PlayStoreDeferredComponentManager)
#   Execution failed for task ':app:minifyReleaseWithR8'
#
# The references are genuinely unreachable — nothing constructs that manager unless deferred
# components are enabled — so R8 strips the class and the dangling references go with it. Adding
# the Play Core dependency instead would ship a library the app never calls.
-dontwarn com.google.android.play.core.**
