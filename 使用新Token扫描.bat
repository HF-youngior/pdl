@echo off
chcp 65001 >nul
echo ========================================
echo SonarQube Scan Script - Using New Token
echo ========================================

echo Setting environment variables...
set SONAR_HOME=D:\sonarqube-25.12.0.117093
set SONAR_SCANNER_HOME=D:\sonar-scanner-4.8.0.2856

echo Checking SonarQube service status...
netstat -ano | findstr :9000 >nul
if %errorlevel% neq 0 (
    echo Error: SonarQube service is not running, starting...
    call "%SONAR_HOME%\bin\windows-x86-64\StartSonar.bat"
    timeout /t 60 /nobreak >nul
    netstat -ano | findstr :9000 >nul
    if %errorlevel% neq 0 (
        echo Error: SonarQube service failed to start
        pause
        exit /b 1
    )
)

echo SonarQube service is running
echo.

echo Opening SonarQube Web interface for project setup...
echo Admin credentials:
echo Username: admin
echo Password: asdfgh0625@YYH
echo.
start http://localhost:9000

echo.
echo If project 'pdl' doesn't exist, please:
echo 1. Login with admin/asdfgh0625@YYH
echo 2. Create project with key 'pdl'
echo 3. Name it 'PDL企业管理系统'
echo 4. Return to this window and press any key to continue
echo.
pause

echo Scanning with new Token...
echo Token: sqp_ca5888234671bfe3514420a0e8ce3dbedee3782d
echo.

"%SONAR_SCANNER_HOME%\bin\sonar-scanner.bat" -D sonar.login=sqp_ca5888234671bfe3514420a0e8ce3dbedee3782d

if %errorlevel% equ 0 (
    echo.
    echo Scan completed successfully!
    echo Please visit http://localhost:9000/dashboard?id=pdl to view results
) else (
    echo.
    echo Scan failed, please check error messages
    echo You may need to:
    echo 1. Create project in SonarQube Web interface
    echo 2. Ensure Token has sufficient permissions
    echo 3. Check project configuration file
)

echo.
pause