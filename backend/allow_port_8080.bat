@echo off
chcp 65001 >nul
echo ========================================
echo 配置 Windows 防火墙允许 8080 端口
echo ========================================
echo.
echo 此脚本需要管理员权限
echo.

:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo 错误: 需要管理员权限！
    echo 请右键点击此文件，选择"以管理员身份运行"
    pause
    exit /b 1
)

echo 正在配置防火墙规则...
powershell -ExecutionPolicy Bypass -File "%~dp0allow_port_8080.ps1"

pause



