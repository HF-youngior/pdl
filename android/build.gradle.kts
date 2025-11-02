allprojects {
    repositories {
        maven { url=uri ("https://www.jitpack.io")}
        maven { url=uri ("https://maven.aliyun.com/repository/releases")}
        maven { url=uri ("https://maven.aliyun.com/repository/google")}
        maven { url=uri ("https://maven.aliyun.com/repository/central")}
        maven { url=uri ("https://maven.aliyun.com/repository/gradle-plugin")}
        maven { url=uri ("https://maven.aliyun.com/repository/public")}

        google()
        mavenCentral()
    }
}

// 注释掉自定义构建目录，避免跨驱动器路径问题
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
