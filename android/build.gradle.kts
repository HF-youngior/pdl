allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 与 Flutter 默认目录保持一致，方便 flutter 工具在根目录 build/ 下查找产物
val flutterRootBuildDir = rootDir.resolve("../build").canonicalFile
val androidRootPath = rootDir.canonicalFile.toPath()

buildDir = flutterRootBuildDir

subprojects {
    val projectPath = project.projectDir.canonicalFile.toPath()
    if (projectPath.startsWith(androidRootPath)) {
        val subprojectDir = flutterRootBuildDir.resolve(name)
        buildDir = subprojectDir
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
