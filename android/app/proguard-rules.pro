# flutter_local_notifications stores scheduled notifications as JSON and reads
# them back with Gson TypeToken. R8 must preserve generic signatures, otherwise
# release builds can crash with:
# "TypeToken must be created with a type argument".
-keepattributes Signature
-keepattributes *Annotation*

-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.flutterlocalnotifications.** { *; }
