@echo off
chcp 65001 >nul
echo ========================================
echo 显示电脑IP地址和服务器配置信息
echo ========================================
echo.

echo 【当前网络配置】
echo.
ipconfig | findstr /i "IPv4" | findstr /v "127.0.0.1"
echo.

echo 【服务器状态】
netstat -ano | findstr :8080 >nul
if %errorlevel% equ 0 (
    echo ✅ 后端服务器正在运行（端口 8080）
    netstat -ano | findstr :8080
) else (
    echo ❌ 后端服务器未运行
    echo    请运行: start_enterprise_backend_correct.bat
)
echo.

echo 【防火墙规则】
netsh advfirewall firewall show rule name="Flutter Backend Server Port 8080" >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ 防火墙规则已配置
) else (
    echo ❌ 防火墙规则未配置
    echo    请运行: allow_port_8080.bat
)
echo.

echo ========================================
echo 【手机访问地址】
echo ========================================
echo.
setlocal enabledelayedexpansion
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4" ^| findstr /v "127.0.0.1"') do (
    set IP=%%a
    set IP=!IP:~1!
    echo 请在手机浏览器或Flutter应用中配置以下地址：
    echo.
    echo   IP地址: !IP!
    echo   端口: 8080
    echo   完整URL: http://!IP!:8080/api
    echo.
    echo 手机浏览器测试地址：
    echo   http://!IP!:8080/api/departments
    echo.
    goto :found
)
:found
endlocal

echo ========================================
echo 【配置Flutter应用】
echo ========================================
echo.
echo 方法1：在应用设置中配置服务器地址
echo   1. 打开Flutter应用
echo   2. 进入"设置"页面
echo   3. 找到"服务器配置"
echo   4. 输入上面的IP地址和端口
echo.
echo 方法2：通过代码配置（需要修改代码）
echo   在应用启动时设置：
echo   await ServerConfigService.setServerHost('上面的IP地址');
echo   await ServerConfigService.setServerPort('8080');
echo.

echo ========================================
echo 按任意键退出...
echo ========================================
pause >nul

