import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload signing credentials, kept out of the repository.
//
// A release build needs android/key.properties, which is deliberately not
// committed: it names a keystore and holds its passwords. See
// android/key.properties.example and docs/RELEASING.md.
//
// Without it, release builds still work but are signed with the debug key, so
// they run on a device and cannot be uploaded to Play. That is the right
// failure: a contributor cloning this repo should be able to build and run
// without needing Paul's signing key.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasUploadKey = keystorePropertiesFile.exists()

if (hasUploadKey) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "io.github.pkellyuk.kylesvoice"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.github.pkellyuk.kylesvoice"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("upload")
            } else {
                // No upload key present: sign with the debug key so the build
                // still runs on a device. It cannot be uploaded to Play, which
                // is exactly what should happen.
                signingConfigs.getByName("debug")
            }

            // Shrink and obfuscate. Flutter's own rules keep the engine intact.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
