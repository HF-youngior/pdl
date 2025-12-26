@echo off
chcp 65001 >nul
echo ========================================
echo 运行 Newman 测试并生成报告
echo ========================================
echo.

cd /d "%~dp0\..\backend"

echo [1/3] 检查 Newman 是否已安装...
npx newman --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Newman 未安装，正在安装...
    npm install newman newman-reporter-htmlextra --save-dev
    if %errorlevel% neq 0 (
        echo ❌ 安装失败，请手动安装: npm install -g newman newman-reporter-htmlextra
        pause
        exit /b 1
    )
) else (
    echo ✅ Newman 已安装
)

echo.
echo [2/3] 检查后端服务是否运行...
curl -s http://localhost:8080/api >nul 2>&1
if %errorlevel% neq 0 (
    echo ⚠️  警告: 后端服务可能未运行在 http://localhost:8080
    echo    请确保后端服务已启动后再运行测试
    echo.
    pause
)

echo.
echo [3/3] 运行 Newman 测试...
npx newman run enterprise-api-collection.json -r htmlextra --reporter-htmlextra-export newman-full-report.html

if %errorlevel% equ 0 (
    echo.
    echo ✅ 测试完成！报告已生成: backend\newman-full-report.html
    echo.
    echo 是否要打开报告？(Y/N)
    set /p open="> "
    if /i "%open%"=="Y" (
        start newman-full-report.html
    )
) else (
    echo.
    echo ❌ 测试运行失败，请检查错误信息
)

echo.
pause

