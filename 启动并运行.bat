@echo off
chcp 65001 >nul
echo ================================================
echo    企业管理系统 - 启动脚本
echo ================================================
echo.

echo [1/3] 启动后端服务器...
start "后端服务器" cmd /k "cd backend && node server_enterprise.js"
echo 后端服务器正在启动...
timeout /t 3 /nobreak >nul
echo.

echo [2/3] 启动Android模拟器...
flutter emulators --launch Medium_Phone_API_36.1
echo 等待模拟器启动...
timeout /t 5 /nobreak >nul
echo.

echo [3/3] 运行Flutter应用...
echo.
echo ================================================
echo   正在启动应用...
echo ================================================
echo.
echo 提示: 
echo   - 如果首次运行，请等待依赖下载完成
echo   - 网页端地址: http://localhost:8080/web_admin
echo   - 后端API: http://localhost:8080/api
echo.
flutter run

pause

