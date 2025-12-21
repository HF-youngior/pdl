@echo off
chcp 65001 >nul
echo 🔗 SonarQube项目配置向导
echo ==========================
echo.

echo 📋 当前项目信息:
echo 项目Key: PDL-Enterprise-Management
echo 项目名称: PDL企业管理系统
echo SonarQube地址: http://localhost:9000
echo.

echo 🔍 检查SonarQube连接...
curl -s http://localhost:9000/api/system/status | findstr "UP" >nul
if %errorlevel% equ 0 (
    echo ✅ SonarQube服务正常运行
) else (
    echo ❌ SonarQube服务未响应
    echo 💡 请确保SonarQube已启动
    pause
    exit /b 1
)

echo.
echo 🎯 配置目标:
echo 1. 项目已在SonarQube中注册
echo 2. 扫描数据已上传
echo 3. 可直接访问项目仪表板
echo.

echo 📱 直接访问方式:
echo ==================
echo.
echo 🌐 主页访问:
echo    http://localhost:9000
echo.
echo 📊 项目仪表板直接访问:
echo    http://localhost:9000/dashboard?id=PDL-Enterprise-Management
echo.
echo 🔍 问题查看:
echo    http://localhost:9000/project/issues?id=PDL-Enterprise-Management
echo.
echo 📈 代码度量:
echo    http://localhost:9000/component_measures?id=PDL-Enterprise-Management
echo.

echo 🚀 正在打开项目页面...
start http://localhost:9000/dashboard?id=PDL-Enterprise-Management

echo.
echo 💡 如果页面显示"项目不存在"，需要:
echo 1. 确保已执行代码扫描
echo 2. 检查项目Key是否正确
echo 3. 验证Token权限
echo.

echo 🔧 手动执行扫描命令:
echo ====================
echo 如果需要重新扫描，请运行:
echo.
echo 方式1 - 使用官方Scanner:
echo   sonar-scanner
echo.
echo 方式2 - 使用自定义脚本:
echo   node run_security_scan.js
echo.

echo 📋 登录信息:
echo =============
echo 默认账号: admin
echo 默认密码: admin
echo 首次登录需要修改密码
echo.

pause