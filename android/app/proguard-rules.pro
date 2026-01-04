# Keep rules for pdfbox-android optional JP2 codec references to avoid R8 missing class error
# The JP2 decoder/encoder are optional; we can suppress warnings safely.
-dontwarn com.gemalto.jp2.**

# General keeps for pdfbox-android (be conservative)
-keep class com.tom_roush.** { *; }
-keep class org.apache.commons.logging.** { *; }


