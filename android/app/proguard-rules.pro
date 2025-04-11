# Flutter Core
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# MainActivity - adjust package if changed
-keep class com.example.hr_attendance.MainActivity { *; }

# Annotations (common in reflection)
-keepattributes *Annotation*

# Native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Serializable support
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Parcelable support
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Kotlin and Kotlinx
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-keepclassmembers class ** {
    @kotlin.Metadata *;
}

# Firebase / Google Play Services (optional, if used)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Optional: Play Core / SplitInstall support (avoid R8 missing class crash)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Flutter Deferred Components (safe default even if unused)
-dontwarn com.google.android.play.**
-dontwarn com.google.android.gms.**

# Secure Storage plugins
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# WebView JS Interface (used in some plugins)
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
