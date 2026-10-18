allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Ép mọi plugin Android dùng cùng NDK đã cài sẵn (tránh tự tải NDK khác)
subprojects {
    afterEvaluate {
        extensions
            .findByType(com.android.build.gradle.BaseExtension::class.java)
            ?.ndkVersion = "27.0.12077973"
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
