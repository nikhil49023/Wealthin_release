# Flutter / Dart rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }

# Chaquopy (Python bridge)
-keep class com.chaquo.** { *; }
-keep class com.chaquo.python.** { *; }

# Supabase / HTTP
-keep class io.supabase.** { *; }

# Keep annotations
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes InnerClasses

# Kotlin serialization
-keepclassmembers class kotlinx.serialization.** { *; }

# Flutter secure storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Permission handler
-keep class com.baseflow.** { *; }

# SMS Inbox plugin
-keep class com.moez.** { *; }
-keep class com.moez.QKSMS.** { *; }

# SQLite / sqflite
-keep class com.tekartik.sqflite.** { *; }

# Suppress warnings for common libraries
-dontwarn com.google.android.play.core.**
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
