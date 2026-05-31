import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePropertiesFile = rootProject.file("key.properties")
val releaseKeystoreProperties = Properties()
if (releaseKeystorePropertiesFile.exists()) {
    releaseKeystorePropertiesFile.inputStream().use { releaseKeystoreProperties.load(it) }
}

fun releaseSigningProperty(name: String): String {
    val value = releaseKeystoreProperties.getProperty(name)?.trim()
    if (value.isNullOrEmpty()) {
        throw GradleException(
            "Missing '$name' in android/key.properties. " +
                "Release builds must be signed with a real upload keystore.",
        )
    }
    return value
}

fun validateReleaseSigningProperties() {
    if (!releaseKeystorePropertiesFile.exists()) {
        throw GradleException(
            "Missing android/key.properties. Create it from android/key.properties.example " +
                "and point storeFile to your real release/upload keystore. " +
                "Release builds are not allowed to use debug signing.",
        )
    }

    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        .forEach(::releaseSigningProperty)

    val storeFile = rootProject.file(releaseSigningProperty("storeFile"))
    if (!storeFile.exists()) {
        throw GradleException(
            "Release keystore not found at ${storeFile.path}. " +
                "Check storeFile in android/key.properties.",
        )
    }
}

android {
    namespace = "es.focusclub.clientes.app_focus_club"
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
        applicationId = "es.focusclub.clientes.app_focus_club"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseKeystorePropertiesFile.exists()) {
                validateReleaseSigningProperties()
                keyAlias = releaseSigningProperty("keyAlias")
                keyPassword = releaseSigningProperty("keyPassword")
                storeFile = rootProject.file(releaseSigningProperty("storeFile"))
                storePassword = releaseSigningProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

gradle.taskGraph.whenReady {
    val releaseTaskRequested = allTasks.any { task ->
        task.name.contains("Release", ignoreCase = true)
    }
    if (releaseTaskRequested) {
        validateReleaseSigningProperties()
    }
}
