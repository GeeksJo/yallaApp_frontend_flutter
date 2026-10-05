import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Host [DEFAULT] Firebase. Needs android/app/google-services.json; until
    // that file is added the Android build fails with "File
    // google-services.json is missing". That is deliberate - a Firebase that
    // configured itself silently would mean no kill switch and no push, with
    // nothing on screen to notice.
    id("com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists().also { exists ->
    if (exists) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }
}

android {
    namespace = "com.majoon.yalla"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // 17, not 11: the plus-plugins (package_info, device_info, share)
        // compile to JVM 17, and a JVM 11 app cannot consume them.
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    // Kotlin 2.3+ rejects the old `kotlinOptions { jvmTarget = "11" }` string
    // form outright ("Using 'jvmTarget: String' is an error").
    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.majoon.yalla"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile")!!)
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Play policy (Aug 2026): Billing Library 8+ required; Google recommends 9.x.
    // game_kit IAP uses in_app_purchase_android (BillingClient). Older plugin
    // releases pulled 7.x and triggered Play Console warnings on shipped AABs.
    implementation("com.android.billingclient:billing:9.1.0")

    // LevelPlay network adapters. The unity_levelplay_mediation plugin ships
    // only the mediation SDK core, and game_kit is a pure Dart package with no
    // android/ of its own, so each host app declares the adapters it needs.
    // The Unity Ads SDK is not pulled in transitively by the adapter.
    //
    // A missing adapter fails SILENTLY: the SDK initialises, the dashboard
    // shows the instance live, and no ad ever loads. Grep logcat for
    // "adapter was not loaded". See game_kit docs/LEVELPLAY_SETUP.md.
    implementation("com.unity3d.ads-mediation:unityads-adapter:5.5.0")
    implementation("com.unity3d.ads:unity-ads:4.16.6")
}
