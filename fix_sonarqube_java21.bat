@echo off
chcp 65001 >nul
echo ========================================
echo SonarQube Java 21 兼容性修复工具
echo ========================================
echo.

echo 问题分析:
echo SonarQube 9.9.0 内置的Elasticsearch与Java 21不兼容
echo 错误: The Security Manager is deprecated and will be removed
echo.

echo 解决方案选项:
echo.
echo 方案1: 安装Java 17 (推荐)
echo ----------------------------------------
echo 这是SonarQube 9.9.0官方支持的Java版本
echo 下载地址: https://adoptium.net/temurin/releases/?version=17
echo.
echo 步骤:
echo 1. 下载并安装Java 17
echo 2. 设置JAVA_HOME环境变量指向Java 17
echo 3. 重新启动SonarQube
echo.

echo 方案2: 下载新版SonarQube (兼容Java 21)
echo ----------------------------------------
echo SonarQube 10.x版本支持Java 21
echo 下载地址: https://www.sonarsource.com/downloads/
echo.

echo 方案3: 临时修复当前版本
echo ----------------------------------------
echo 修改Elasticsearch启动参数以绕过Security Manager问题
echo 注意: 这可能影响安全性，仅用于测试环境
echo.

echo 正在尝试临时修复...
echo.

set SONAR_ES_JVM_OPTIONS=D:\sonarqube-9.9.0.65466\elasticsearch\config\jvm.options

if exist "%SONAR_ES_JVM_OPTIONS%" (
    echo 正在备份原始配置文件...
    copy "%SONAR_ES_JVM_OPTIONS%" "%SONAR_ES_JVM_OPTIONS%.backup" >nul 2>&1
    
    echo 正在添加Java 21兼容性参数...
    echo -Djava.security.manager=allow >> "%SONAR_ES_JVM_OPTIONS%"
    
    echo 配置文件已更新
) else (
    echo 警告: 找不到Elasticsearch配置文件
    echo 请手动添加参数: -Djava.security.manager=allow
)

echo.
echo 修复完成! 请重新启动SonarQube:
echo D:\sonarqube-9.9.0.65466\bin\windows-x86-64\StartSonar.bat
echo.
echo 如果仍有问题，建议使用方案1安装Java 17
echo.
pause