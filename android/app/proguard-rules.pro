# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase Messaging - keep classes that R8 strips in release builds
-keep class io.flutter.plugins.firebase.messaging.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.** { *; }

# Prevent R8 from stripping Firebase background service & context holder
-keep class io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingBackgroundService { *; }
-keep class io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingInitProvider { *; }
-keep class io.flutter.plugins.firebase.messaging.ContextHolder { *; }

# General Android keep rules
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
