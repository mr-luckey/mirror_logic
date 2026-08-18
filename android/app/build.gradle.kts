import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase remains optional for local builds. Once the Firebase Console file is
// present, this processes it into the Android resources consumed by Firebase.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Upload key for the Play Store, kept out of the repository. Without this file
// a release build falls back to the debug key, which Play rejects on upload
// rather than accepting under the wrong certificate.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.appwaretech.mirrorlogic"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.appwaretech.mirrorlogic"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8 stays off. The game is a single module with no reflection-heavy
            // dependencies, so shrinking buys little, and every crash report
            // arrives readable instead of needing a mapping file.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    implementation("androidx.annotation:annotation:1.9.1")
    implementation("com.facebook.android:audience-network-sdk:6.22.0")
}

flutter {
    source = "../.."
}
