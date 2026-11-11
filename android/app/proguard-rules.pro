# Meta Audience Network (LevelPlay facebook-adapter), rules from LevelPlay's
# Android Meta guide. The AAR ships consumer rules too; these are the published
# set, kept so a future AAR without them cannot strip the adapter's entry points.
-dontwarn com.facebook.ads.internal.**
-keeppackagenames com.facebook.*
-keep public class com.facebook.ads.** {*;}
-keep public class com.facebook.ads.**{ public protected *; }
