@echo off
echo ========================================
echo 运行SonarQube代码扫描
echo ========================================

REM 设置环境变量
set SONAR_HOME=D:\sonarqube-25.12.0.117093
set SONAR_SCANNER_HOME=D:\sonar-scanner-4.8.0.2856
set PATH=%PATH%;%SONAR_SCANNER_HOME%\bin

REM 检查SonarQube服务是否运行
netstat -ano | findstr :9000 >nul
if %errorlevel% neq 0 (
    echo 错误: SonarQube服务未运行
    echo 请先运行"启动SonarQube服务.bat"
    pause
    exit /b 1
)

echo 正在运行SonarQube扫描...
cd /d F:\pdl
sonar-scanner -D sonar.login=sqp_5d7884ce3957f7c0f5449d1a8d5a9bd1ec355d49

echo.
echo 扫描完成!
echo 查看报告: http://localhost:9000/dashboard?id=pdl
echo.
pause