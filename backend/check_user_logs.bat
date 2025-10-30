@echo off
echo 正在查询用户个人日志信息...
echo.
cd /d "%~dp0"
node check_user_logs.js
echo.
echo 查询完成！
pause


