import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: the upload keystore and its key.properties live OUTSIDE the repo (default
// /home/box/keys/key.properties, or the path in env NEWLIFE_KEY_PROPERTIES). Never committed.
val keyPropsFile = file(System.getenv("NEWLIFE_KEY_PROPERTIES") ?: "/home/box/keys/key.properties")
val keyProps = Properties().apply { if (keyPropsFile.exists()) load(FileInputStream(keyPropsFile)) }

android {
    namespace = "app.thetoms.newlifeuk"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.thetoms.newlifeuk"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keyPropsFile.exists()) {
                keyAlias = keyProps["keyAlias"] as String
                keyPassword = keyProps["keyPassword"] as String
                storeFile = file(keyProps["storeFile"] as String)
                storePassword = keyProps["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Signed with the upload key when key.properties exists. Debug keys only with ALLOW_DEBUG_SIGNED_RELEASE=1
            // (local smoke tests); otherwise the build stops, so a debug-signed build can never be uploaded by mistake.
            signingConfig = if (keyPropsFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
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

gradle.taskGraph.whenReady {
    val wantsRelease = allTasks.any { it.name.contains("Release") && (it.name.startsWith("assemble") || it.name.startsWith("bundle")) }
    if (wantsRelease && !keyPropsFile.exists() && System.getenv("ALLOW_DEBUG_SIGNED_RELEASE") != "1") {
        throw GradleException("Release build needs the upload key (NEWLIFE_KEY_PROPERTIES). Set ALLOW_DEBUG_SIGNED_RELEASE=1 only for local tests.")
    }
}
