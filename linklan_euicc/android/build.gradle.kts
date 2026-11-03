group = "com.linklan.euicc.linklan_euicc"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.2.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "com.linklan.euicc.linklan_euicc"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

dependencies {
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")

    implementation("com.github.huangzhangliang:LinklanEuiccAndroid:1.1.5")

    implementation("io.grpc:grpc-okhttp:1.64.0")
    implementation("io.grpc:grpc-protobuf-lite:1.64.0")
    implementation("io.grpc:grpc-stub:1.64.0")
    implementation("com.squareup.okhttp3:okhttp:4.8.0")
    implementation("org.apache.tomcat:annotations-api:6.0.53")

    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    implementation("com.squareup.retrofit2:adapter-rxjava:2.7.1")
    implementation("com.squareup.okhttp3:logging-interceptor:4.8.0")


    implementation ("androidx.compose.ui:ui-tooling:1.7.0")
    implementation ("androidx.compose.animation:animation:1.7.0")
    implementation ("androidx.compose.runtime:runtime:1.7.0")
    implementation ("androidx.compose.runtime:runtime-livedata:1.7.0")
    implementation ("androidx.compose.runtime:runtime-rxjava2:1.7.0")
    implementation ("androidx.compose.material3:material3:1.3.2")

    implementation ("androidx.core:core-ktx:1.13.1")
    implementation ("androidx.lifecycle:lifecycle-runtime-ktx:2.8.3")
    implementation ("androidx.lifecycle:lifecycle-viewmodel-ktx:2.8.3")
    implementation ("androidx.lifecycle:lifecycle-livedata-ktx:2.8.3")
    implementation ("androidx.lifecycle:lifecycle-extensions:2.2.0")

    implementation("io.reactivex.rxjava2:rxjava:2.1.12")
    implementation("org.slf4j:slf4j-api:1.7.36")
    implementation("org.slf4j:slf4j-android:1.7.36")
    implementation("org.bouncycastle:bcprov-jdk15to18:1.68")

}
