import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Optional until Firebase is configured. Use matching files for both flavors;
// see docs/NOTIFICATIONS.md. A root file containing both clients also works.
if (file("google-services.json").exists() ||
    file("src/customer/google-services.json").exists() ||
    file("src/staff/google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

val signingProperties = Properties()
val signingFile = rootProject.file("key.properties")
if (signingFile.exists()) signingFile.inputStream().use { signingProperties.load(it) }

android {
    namespace = "vn.smartpark.smartpark"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "vn.smartpark.smartpark"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appName"] = "SmartPark"
    }

    flavorDimensions += "role"
    productFlavors {
        create("customer") {
            dimension = "role"
            applicationIdSuffix = ".customer"
        }
        create("staff") {
            dimension = "role"
            applicationIdSuffix = ".staff"
            manifestPlaceholders["appName"] = "SmartPark Staff"
        }
    }

    signingConfigs {
        if (signingFile.exists()) {
            create("release") {
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
                storeFile = file(signingProperties.getProperty("storeFile"))
                storePassword = signingProperties.getProperty("storePassword")
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
            proguardFiles("proguard-rules.pro")
        }
    }
}

// Fail rather than silently distributing a release signed with the debug key.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("Release") } && !signingFile.exists()) {
        throw GradleException("Release signing requires android/key.properties; see docs/RELEASE_BUILD.md")
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
