plugins {
    // Google services Gradle plugin 추가
    id("com.google.gms.google-services") version "4.4.3" apply false
    // ⬇️⬇️ [수정 추가] Android 및 Kotlin 플러그인 선언 ⬇️⬇️
    //id("com.android.application") version "8.0.0" apply false
    //id("org.jetbrains.kotlin.android") version "1.7.10" apply false
}


allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
