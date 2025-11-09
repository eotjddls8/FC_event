plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.jonglee.pionevent"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.jonglee.pionevent"
        minSdk = flutter.minSdkVersion  // 이렇게 수정
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    signingConfigs {
        create("release") {
            storeFile = file("../../upload-keystore.jks")
            storePassword = "ljc112233"
            keyAlias = "upload"
            keyPassword = "ljc112233"
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter { source = "../.." }

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.0.0"))
    implementation("com.google.firebase:firebase-analytics")
}