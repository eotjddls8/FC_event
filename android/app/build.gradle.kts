import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")      // ← 최신 권장 플러그인 id
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.jonglee.pionevent"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.jonglee.pionevent"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = 2
        versionName = "2.0.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions { jvmTarget = "17" }

    signingConfigs {
        create("release") {
            val keystoreFile = file("${rootDir.parentFile.absolutePath}/key.properties")
            val keystore = Properties()
            if (keystoreFile.exists()) {
                keystoreFile.inputStream().use { keystore.load(it) }
                println("✓ key.properties loaded successfully")
            } else {
                println("✗ key.properties not found at: ${keystoreFile.absolutePath}")
            }

            val storeFileValue = keystore.getProperty("storeFile", "../../upload-keystore.jks")
            val storePasswordValue = keystore.getProperty("storePassword")
            val keyAliasValue = keystore.getProperty("keyAlias")
            val keyPasswordValue = keystore.getProperty("keyPassword")

            storeFile = file(storeFileValue)
            storePassword = storePasswordValue
            keyAlias = keyAliasValue
            keyPassword = keyPasswordValue
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            // 필요 시 proguard/r8 옵션 추가
        }
    }
}

flutter {
    source = "../.."
}

// ⚠️ FlutterFire가 네이티브 의존성을 자동으로 관리합니다.
// firebase_analytics를 쓰려면 pubspec.yaml에만 추가하세요.
// 아래 dependencies 블록은 지우는 것을 권장합니다.

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.0.0"))
    implementation("com.google.firebase:firebase-analytics")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

}

