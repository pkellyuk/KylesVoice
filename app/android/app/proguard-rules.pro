# Kyle's Voice ProGuard rules.
#
# Flutter supplies its own rules for the engine; these cover the plugins used
# here. Each entry exists because the class is reached by reflection or from
# native code, where the shrinker cannot see the reference.

# flutter_tts reaches Android's speech engine through the platform channel.
-keep class io.flutter.plugins.** { *; }

# Play Core is referenced by Flutter's deferred-components support, which this
# app does not use. Without this the shrinker warns about classes that are
# never actually needed at runtime.
-dontwarn com.google.android.play.core.**
