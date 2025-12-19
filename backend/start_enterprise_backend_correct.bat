@echo off
chcp 65001 >nul
echo Starting Enterprise Management System Backend Service...
echo.

REM Check Node.js
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Node.js not found, please install Node.js first
    pause
    exit /b 1
)

REM Check package.json
if not exist package.json (
    echo Error: package.json not found
    echo Please ensure you are in the backend directory
    pause
    exit /b 1
)

REM Install dependencies if needed
if not exist node_modules (
    echo Installing dependencies...
    npm install
    if %errorlevel% neq 0 (
        echo Error: Failed to install dependencies
        pause
        exit /b 1
    )
)

REM Set environment variables
set NODE_ENV=development
set PORT=8080
set DB_HOST=rm-2zeoa1b89ga70ikpifo.mysql.rds.aliyuncs.com
set DB_USER=pdl123
set DB_PASSWORD=Pdl1234567
set DB_NAME=enterprise_management
set DB_PORT=3306
set JWT_SECRET=enterprise-management-secret-key-2024

echo Environment Configuration:.
echo   Port: %PORT%
echo   Database: %DB_NAME%
echo   Environment: %NODE_ENV%
echo   MySQL Password: Pdl1234567
echo.

echo Starting server...
echo Press Ctrl+C to stop the server
echo.

REM Start server
node server_enterprise.js

pause
