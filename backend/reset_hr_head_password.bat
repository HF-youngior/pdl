@echo off
chcp 65001 >nul
echo ========================================
echo 重置 hr_head 用户密码脚本
echo ========================================
echo.
echo 此脚本会将 hr_head 用户的密码重置为 hr123
echo.

cd /d %~dp0

echo 正在运行 Node.js 脚本...
node reset_hr_head_password.js

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ 密码重置成功！
    echo.
    echo 现在可以使用以下凭据登录:
    echo   用户名: hr_head
    echo   密码: hr123
) else (
    echo.
    echo ❌ 密码重置失败，请检查错误信息
)

echo.
pause





