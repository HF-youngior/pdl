@echo off
echo ========================================
echo    企业管理系统Web管理端启动
echo ========================================
echo.
echo 正在启动Web管理端...
echo.
echo 注意：请确保后端服务器已启动！
echo 如果后端服务器未启动，请先运行 start_backend.bat
echo.
start "" "web_admin\index.html"
echo.
echo Web管理端已在浏览器中打开
echo 如果无法访问，请检查后端服务器是否正在运行
echo.
pause
