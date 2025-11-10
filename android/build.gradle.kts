allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 注释掉自定义构建目录配置，避免与 Flutter 插件路径冲突
// 当构建目录和插件路径在不同驱动器时（如 F:\ 和 C:\），会导致路径计算错误
// val newBuildDir: Directory =
//     rootProject.layout.buildDirectory
//         .dir("../../build")
//         .get()
// rootProject.layout.buildDirectory.value(newBuildDir)
//
// subprojects {
//     val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
//     project.layout.buildDirectory.value(newSubprojectBuildDir)
// }

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
