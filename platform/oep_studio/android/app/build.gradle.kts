plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.oep.oep_studio"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.oep.oep_studio"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // AP-OEP-DIAGRAM-ANDROID-001: the legacy V2 wiring app
    // (reference/legacy_wiring_sim_v2/eke-wiring-sim/) is loaded on
    // Android as a native Android asset (file:///android_asset/...),
    // NOT as a Flutter asset — Flutter's own asset bundler silently
    // drops any `pubspec.yaml` asset entry that resolves outside the
    // Flutter package directory (confirmed: `../../reference/...`
    // entries produced zero files under `build/flutter_assets/`), so
    // `loadFlutterAsset` cannot reach this directory. Android's Gradle
    // asset source sets have no such restriction, so this extra
    // `srcDirs` entry lets the app load the exact same, unmodified
    // repository files the Windows host loads via `file://` — no copy
    // into the Studio source tree, matching that host's own principle.
    sourceSets {
        getByName("main") {
            assets.srcDirs("../../../../reference/legacy_wiring_sim_v2/eke-wiring-sim")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
