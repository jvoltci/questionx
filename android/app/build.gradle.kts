import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase plugins are applied only when google-services.json is present.
// See ../FIREBASE_SETUP.md for one-time configuration steps.
val googleServicesFile = file("google-services.json")
if (googleServicesFile.exists()) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.northmountain.questionx"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.northmountain.questionx"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Never silently fall back to the debug key for a release build.
            // If key.properties is absent the release stays UNSIGNED (Play / install
            // will reject it) instead of shipping a debug-signed "release".
            signingConfig = signingConfigs.findByName("release")

            ndk {
                // Flutter ships libflutter.so UNSTRIPPED (~140 MB per ABI) and
                // relies on AGP to strip the copy that ships and move the symbols
                // into BUNDLE-METADATA as libflutter.so.sym. AGP only extracts
                // those symbols when a debugSymbolLevel is declared, and
                // `flutter build appbundle` looks for exactly that file to decide
                // whether stripping succeeded.
                //
                // Do NOT "fix" a strip warning with
                // `packaging { jniLibs { doNotStrip.add("**/*.so") } }` — that was
                // tried in da8e9bc and does the opposite of what is wanted: it
                // keeps every debug symbol in the shipped AAB (147 MB, arm64
                // libflutter.so reporting "with debug_info, not stripped") while
                // still producing no .sym, so the check fails anyway.
                debugSymbolLevel = "SYMBOL_TABLE"
            }
        }
    }
}

flutter {
    source = "../.."
}
