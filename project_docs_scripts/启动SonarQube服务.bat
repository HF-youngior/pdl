@echo off
echo ========================================
echo 启动SonarQube服务
echo ========================================

REM 检查SonarQube是否已安装
if not exist "D:\sonarqube-25.12.0.117093" (
    echo 错误: SonarQube未安装在D:\sonarqube-25.12.0.117093目录
    pause
    exit /b 1
)

REM 设置环境变量
set SONAR_HOME=D:\sonarqube-25.12.0.117093
set SONAR_SCANNER_HOME=D:\sonar-scanner-4.8.0.2856
set PATH=%PATH%;%SONAR_SCANNER_HOME%\bin

echo 正在启动SonarQube服务...
cd /d %SONAR_HOME%\bin\windows-x86-64
start "SonarQube Server" /min StartSonar.bat

echo 等待SonarQube服务启动...
echo 注意: SonarQube首次启动可能需要2-3分钟，请耐心等待
timeout /t 60 /nobreak >nul

echo 检查SonarQube服务状态...
netstat -ano | findstr :9000 >nul
if %errorlevel% == 0 (
    echo SonarQube服务已成功启动!
    echo 访问地址: http://localhost:9000
    echo 默认用户名: admin
    echo 默认密码: admin
) else (
    echo 警告: SonarQube服务可能还在启动中
    echo 请稍后访问: http://localhost:9000
    echo 如果长时间无法访问，请检查日志: %SONAR_HOME%\logs
)

echo.
echo 现在可以运行SonarQube扫描了
echo 扫描命令: sonar-scanner -D sonar.login=sqp_5d7884ce3957f7c0f5449d1a8d5a9bd1ec355d49
echo.
pause