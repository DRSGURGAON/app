import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing with the owner's Play UPLOAD key. Never committed: read from
// android/key.properties (git-ignored) or from environment variables:
//   storeFile=/absolute/path/upload-keystore.jks   (DOCSAFE_UPLOAD_STORE_FILE)
//   storePassword=...                              (DOCSAFE_UPLOAD_STORE_PASSWORD)
//   keyAlias=upload                                (DOCSAFE_UPLOAD_KEY_ALIAS)
//   keyPassword=...                                (DOCSAFE_UPLOAD_KEY_PASSWORD)
// Without them, release builds are signed with the debug key (tests/CI only:
// NOT uploadable). -PdocsafeRequireUploadKey=true turns that into an error.
val uploadKey = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
    mapOf(
        "storeFile" to "DOCSAFE_UPLOAD_STORE_FILE",
        "storePassword" to "DOCSAFE_UPLOAD_STORE_PASSWORD",
        "keyAlias" to "DOCSAFE_UPLOAD_KEY_ALIAS",
        "keyPassword" to "DOCSAFE_UPLOAD_KEY_PASSWORD",
    ).forEach { (k, env) -> System.getenv(env)?.let { setProperty(k, it) } }
}
val hasUploadKey = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !uploadKey.getProperty(it).isNullOrBlank() }
if (!hasUploadKey && (project.findProperty("docsafeRequireUploadKey") as String?) == "true") {
    throw GradleException("Upload key not configured: see docs/RELEASE.md")
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
        // Google Play licence key (Play Console -> Monetize -> Licensing): a PUBLIC
        // RSA key used to verify purchase signatures. Not a secret, but it is
        // per-app, so it is supplied at build time (-PdocsafePlayLicenseKey=... or
        // DOCSAFE_PLAY_LICENSE_KEY) instead of being committed. Without it the
        // build cannot verify purchases and Premium can't be bought.
        val playLicenseKey = (project.findProperty("docsafePlayLicenseKey") as String?)
            ?: System.getenv("DOCSAFE_PLAY_LICENSE_KEY")
            ?: uploadKey.getProperty("playLicenseKey")
            ?: ""
        require(Regex("[A-Za-z0-9+/=\\s]*").matches(playLicenseKey)) { "docsafePlayLicenseKey must be base64" }
        buildConfigField("String", "PLAY_LICENSE_KEY", "\"${playLicenseKey.replace(Regex("\\s"), "")}\"")
    }

    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = file(uploadKey.getProperty("storeFile"))
                storePassword = uploadKey.getProperty("storePassword")
                keyAlias = uploadKey.getProperty("keyAlias")
                keyPassword = uploadKey.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasUploadKey) "upload" else "debug")
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
    // Google ML Kit document scanner (UI and camera run inside Google Play services;
    // no camera permission in DocSafe). Same artifact/version the Flutter plugin pins.
    implementation("com.google.android.gms:play-services-mlkit-document-scanner:16.0.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
    // Phase 5 OCR: on-device text recognition, Devanagari model (also reads Latin) bundled
    // in the APK, so nothing is downloaded and no image leaves the device.
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")
    // Phase 6: Google Play Billing (subscriptions). Talks to the Play Store app over
    // IPC; DocSafe itself makes no network requests.
    implementation("com.android.billingclient:billing:8.0.0")

    // Versions aligned with what Flutter's integration_test plugin puts on the debug runtime
    // classpath; Gradle's consistent resolution rejects anything newer here.
    androidTestImplementation("androidx.test:runner:1.3.0")
    androidTestImplementation("androidx.test.ext:junit:1.1.2")
    androidTestImplementation("junit:junit:4.12")
}

flutter {
    source = "../.."
}
