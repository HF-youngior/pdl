@echo off
echo ========================================
echo PDL企业管理系统 - SonarQube静态安全测试
echo ========================================
echo.

REM 检查SonarQube Scanner是否已安装
where sonar-scanner >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] SonarQube Scanner未安装或未添加到PATH环境变量
    echo 请按照以下步骤安装：
    echo 1. 下载SonarQube Scanner: https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/
    echo 2. 解压到本地目录
    echo 3. 将bin目录添加到系统PATH环境变量
    echo 4. 配置SONAR_SCANNER_HOME环境变量
    pause
    exit /b 1
)

REM 显示SonarQube Scanner版本
echo [信息] 检测到的SonarQube Scanner版本：
sonar-scanner --version
echo.

REM 检查配置文件
if not exist "sonar-project.properties" (
    echo [错误] 未找到sonar-project.properties配置文件
    pause
    exit /b 1
)

echo [信息] 开始执行SonarQube扫描...
echo [信息] 项目根目录: %CD%
echo [信息] 配置文件: sonar-project.properties
echo.

REM 执行扫描
sonar-scanner

REM 检查扫描结果
if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo [成功] SonarQube扫描完成！
    echo ========================================
    echo 请访问SonarQube服务器查看详细报告：
    echo - 项目仪表盘: http://localhost:9000/dashboard?id=PDL-Enterprise-Management
    echo - 安全热点: http://localhost:9000/security_hotspots?id=PDL-Enterprise-Management
    echo - 漏洞报告: http://localhost:9000/project/issues?id=PDL-Enterprise-Management&resolved=false&types=VULNERABILITY
    echo.
) else (
    echo.
    echo [错误] SonarQube扫描失败，请检查错误信息
    echo 常见解决方案：
    echo 1. 确保SonarQube服务器正在运行 (http://localhost:9000)
    echo 2. 检查网络连接
    echo 3. 验证项目配置文件
    echo.
)

pause