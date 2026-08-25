# ML Kit text recognition
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
# Keep annotations used by Firebase
-keepattributes *Annotation*

# ── uCrop (image_cropper) ────────────────────────────────────────────────────
#
# Release builds crashed the instant the cropper opened — every profile-photo
# upload, from both Gallery and Camera:
#
#   java.lang.NullPointerException
#     at l.g.inflate(SourceFile:25)
#     at com.yalantis.ucrop.UCropActivity.onCreateOptionsMenu(SourceFile:7)
#
# `onCreateOptionsMenu` inflates uCrop's own menu XML. Resource shrinking had
# removed it, because nothing in *our* sources references it — the only
# reference is inside the library, which the shrinker does not follow. The
# inflater then returned null and the activity died on launch.
#
# Debug builds never showed this: R8 and resource shrinking are release-only.
-keep class com.yalantis.ucrop.** { *; }
-keep interface com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

# ── Plugins that resolve types reflectively ─────────────────────────────────
# These register handlers by name, so R8 cannot see the references and may
# strip or rename them. Each one is a feature the app depends on.
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class com.csdcorp.speech_to_text.** { *; }
-dontwarn com.csdcorp.speech_to_text.**
-keep class com.tundralabs.fluttertts.** { *; }
-dontwarn com.tundralabs.fluttertts.**

# ── Firebase / Play services ────────────────────────────────────────────────
# Model classes are deserialised reflectively; keeping their members prevents
# silently empty documents after minification.
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Kotlin metadata is used by several of the above at runtime.
-keep class kotlin.Metadata { *; }
-keepattributes Signature,InnerClasses,EnclosingMethod,RuntimeVisibleAnnotations
