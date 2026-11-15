import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// Release signing comes from environment variables (CI secrets). Without them the
// release build is signed with the debug key: installable for testing, NOT for Play Store.
val releaseKeystore: String? = System.getenv("SEEDHA_KEYSTORE_FILE")

android {
    namespace = "com.seedhachat.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.seedhachat.app"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
    }

    signingConfigs {
        if (releaseKeystore != null) {
            create("release") {
                storeFile = file(releaseKeystore)
                storePassword = System.getenv("SEEDHA_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("SEEDHA_KEY_ALIAS")
                keyPassword = System.getenv("SEEDHA_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}
