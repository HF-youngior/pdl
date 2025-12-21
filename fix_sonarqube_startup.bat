@echo off
echo ========================================
echo SonarQube启动问题诊断和修复工具
echo ========================================
echo.

echo [诊断] 当前Java版本：
java -version
echo.

echo [问题分析] SonarQube 9.9.0与Java 21兼容性问题：
echo - SonarQube 9.9.0推荐使用Java 11或17
echo - 你当前使用Java 21，可能导致Elasticsearch启动失败
echo.

echo [解决方案] 选择修复方案：
echo 1. 下载并安装Java 17（推荐）
echo 2. 下载兼容Java 21的SonarQube版本
echo 3. 修改SonarQube配置文件强制使用Java 21
echo.

set /p choice="请选择解决方案 (1/2/3): "

if "%choice%"=="1" goto solution1
if "%choice%"=="2" goto solution2  
if "%choice%"=="3" goto solution3
goto end

:solution1
echo.
echo [方案1] 安装Java 17步骤：
echo 1. 访问 https://adoptium.net/temurin/releases/?version=17
echo 2. 下载Windows x64版本的JDK 17
echo 3. 安装到 C:\Program Files\Java\jdk-17\
echo 4. 修改SonarQube的wrapper.conf文件
echo.
echo [自动修复] 正在修改wrapper.conf文件...
set "wrapper_file=D:\sonarqube-9.9.0.65466\conf\wrapper.conf"
if exist "%wrapper_file%" (
    powershell -Command "(Get-Content '%wrapper_file%') -replace 'wrapper.java.command=.*', 'wrapper.java.command=C:\\Program Files\\Java\\jdk-17\\bin\\java' | Set-Content '%wrapper_file%'"
    echo ✅ wrapper.conf已修改为使用Java 17
) else (
    echo ❌ 未找到wrapper.conf文件
)
echo.
echo 修改完成后，请重新启动SonarQube
goto end

:solution2
echo.
echo [方案2] 下载兼容Java 21的SonarQube版本：
echo 1. 访问 https://www.sonarsource.com/downloads/
echo 2. 下载SonarQube 10.0+版本（支持Java 21）
echo 3. 解压到新目录
echo 4. 使用新版本启动
goto end

:solution3
echo.
echo [方案3] 强制使用Java 21（实验性）：
echo [警告] 此方案可能导致不稳定
echo.
echo [自动修复] 正在修改wrapper.conf文件...
set "wrapper_file=D:\sonarqube-9.9.0.65466\conf\wrapper.conf"
if exist "%wrapper_file%" (
    powershell -Command "(Get-Content '%wrapper_file%') -replace 'wrapper.java.additional.1=-Djava.security.egd=file:.*', 'wrapper.java.additional.1=-Djava.security.egd=file:/dev/./urandom' | Set-Content '%wrapper_file%'"
    powershell -Command "(Get-Content '%wrapper_file%') -replace 'wrapper.java.additional.2=-Djava.awt.headless=true', 'wrapper.java.additional.2=-Djava.awt.headless=true' | Set-Content '%wrapper_file%'"
    echo ✅ wrapper.conf已修改
) else (
    echo ❌ 未找到wrapper.conf文件
)
echo.
echo 同时增加内存分配...
powershell -Command "(Get-Content '%wrapper_file%') -replace 'wrapper.java.initmemory=.*', 'wrapper.java.initmemory=1024' | Set-Content '%wrapper_file%'"
powershell -Command "(Get-Content '%wrapper_file%') -replace 'wrapper.java.maxmemory=.*', 'wrapper.java.maxmemory=2048' | Set-Content '%wrapper_file%'"
echo ✅ 内存分配已增加
goto end

:end
echo.
echo ========================================
echo 修复完成！
echo ========================================
echo.
echo 下一步操作：
echo 1. 如果选择了方案1，请先安装Java 17
echo 2. 重新启动SonarQube
echo 3. 检查 http://localhost:9000 是否可访问
echo.
echo 如果仍有问题，请查看日志文件：
echo D:\sonarqube-9.9.0.65466\logs\sonar.log
echo.
pause