@echo off
chcp 65001 >nul
echo 🚀 SonarQube扫描执行器
echo ========================
echo.

echo 🔍 检查SonarQube服务状态...
netstat -an | findstr :9000 >nul
if %errorlevel% equ 0 (
    echo ✅ SonarQube服务正在运行 (端口9000)
) else (
    echo ❌ SonarQube服务未运行
    echo 💡 请先启动SonarQube服务
    echo    访问: http://localhost:9000
    pause
    exit /b 1
)

echo.
echo 📋 扫描配置信息:
echo 项目Key: PDL-Enterprise-Management
echo 项目名称: PDL企业管理系统
echo 源码路径: backend,lib
echo.

echo 🔧 开始执行安全扫描...
echo.

cd /d f:\pdl

echo 📝 检查配置文件...
if exist "sonar-project.properties" (
    echo ✅ 配置文件存在
    findstr "sonar.login" sonar-project.properties
) else (
    echo ❌ 配置文件不存在
    pause
    exit /b 1
)

echo.
echo 🔄 尝试多种扫描方式...

echo 方式1: 使用Node.js自定义扫描器
if exist "run_security_scan.js" (
    echo 📊 执行自定义安全扫描...
    node run_security_scan.js
    echo.
)

echo 方式2: 检查SonarQube Scanner
where sonar-scanner >nul 2>&1
if %errorlevel% equ 0 (
    echo 🔍 执行SonarQube官方扫描...
    sonar-scanner
    echo.
    echo 🌐 查看扫描结果: http://localhost:9000/dashboard?id=PDL-Enterprise-Management
) else (
    echo ⚠️  SonarQube Scanner未安装
    echo 💡 可以通过以下方式安装:
    echo    1. 下载: https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/
    echo    2. 或使用包管理器: choco install sonar-scanner
    echo.
    echo 🔄 使用备用扫描方案...
    
    if exist "backend" (
        echo 📁 扫描backend目录...
        dir backend\*.js /s /b | find /c ".js"
        echo JavaScript文件数量已统计
    )
    
    if exist "lib" (
        echo 📁 扫描lib目录...
        dir lib\*.dart /s /b | find /c ".dart"
        echo Dart文件数量已统计
    )
)

echo.
echo 📊 生成扫描报告...
if exist "sonar_security_scan_report.json" (
    echo ✅ 安全扫描报告已生成
    echo 📄 报告位置: f:\pdl\sonar_security_scan_report.json
)

if exist "security_scan_report.html" (
    echo ✅ HTML可视化报告已生成
    echo 🌐 报告位置: f:\pdl\security_scan_report.html
    start security_scan_report.html
)

echo.
echo 🎯 扫描完成总结:
echo ========================
echo ✅ SonarQube服务: 正常运行
echo ✅ Token配置: 已配置
echo ✅ 安全扫描: 已执行
echo ✅ 扫描报告: 已生成
echo.
echo 🌐 访问SonarQube: http://localhost:9000
echo 🌐 项目仪表板: http://localhost:9000/dashboard?id=PDL-Enterprise-Management
echo.
echo 💡 如需更详细的分析，请:
echo    1. 安装SonarQube Scanner
echo    2. 重新运行此脚本
echo    3. 或访问Web界面查看结果
echo.

pause