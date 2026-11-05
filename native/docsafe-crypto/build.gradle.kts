// Pure-JVM security core for DocSafe.
//
// Contains no Android APIs so it can be compiled and unit-tested on any JVM
// (CI and developer machines without an Android SDK). The Android app
// consumes it through a Gradle composite build (see android/settings.gradle.kts)
// and supplies Android Keystore-backed implementations of [KeyWrapper] and
// [MacProvider].
plugins {
    kotlin("jvm") version "2.4.21"
    `java-library`
}

group = "in.docsafe"
version = "1.0.0"

repositories {
    mavenCentral()
}

// Target Java 17 bytecode (consumed by Android D8) without requiring a JDK 17 toolchain locally.
java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    testImplementation(kotlin("test"))
    testImplementation("org.junit.jupiter:junit-jupiter:5.11.4")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.test {
    useJUnitPlatform()
    testLogging {
        events("failed")
        exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
    }
}
