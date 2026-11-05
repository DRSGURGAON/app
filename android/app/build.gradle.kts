plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "in.docsafe.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "in.docsafe.app"
        // API 26: AES-GCM Keystore keys with reliable TEE support, BiometricPrompt via androidx.
        minSdk = maxOf(26, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            // Release signing is configured in Phase 8 (upload key kept outside the repo).
            // Until then release builds are signed with the debug key and MUST NOT be published.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        resources {
            excludes += setOf("META-INF/LICENSE*", "META-INF/NOTICE*")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("in.docsafe:docsafe-crypto")
    implementation("androidx.biometric:biometric:1.1.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")

    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("junit:junit:4.13.2")
}

flutter {
    source = "../.."
}
