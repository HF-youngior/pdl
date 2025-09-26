@echo off
chcp 65001 >nul
echo 测试Android端连接和API功能...
echo.

echo 1. 检查后端服务是否运行...
curl -s http://localhost:8080/api/departments >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ 后端服务运行正常
) else (
    echo ❌ 后端服务未运行，请先启动 start_enterprise_backend_correct.bat
    pause
    exit /b 1
)

echo.
echo 2. 测试登录API...
curl -X POST http://localhost:8080/api/auth/login ^
-H "Content-Type: application/json" ^
-d "{\"username\":\"admin\",\"password\":\"admin123\"}" ^
-s > temp_login_response.json

if %errorlevel% equ 0 (
    echo ✅ 登录API测试成功
    echo 响应内容:
    type temp_login_response.json
) else (
    echo ❌ 登录API测试失败
)

echo.
echo 3. 测试其他API（需要认证）...
for /f "tokens=2 delims=:" %%a in ('findstr "token" temp_login_response.json') do set TOKEN=%%a
set TOKEN=%TOKEN:"=%
set TOKEN=%TOKEN:,=%
set TOKEN=%TOKEN: =%

echo 测试重要事项API...
curl -H "Authorization: Bearer %TOKEN%" ^
http://localhost:8080/api/important-items ^
-s > temp_items_response.json

if %errorlevel% equ 0 (
    echo ✅ 重要事项API测试成功
    echo 返回项目数量:
    findstr /c:"title" temp_items_response.json | find /c /v ""
) else (
    echo ❌ 重要事项API测试失败
)

echo.
echo 测试任务API...
curl -H "Authorization: Bearer %TOKEN%" ^
http://localhost:8080/api/tasks ^
-s > temp_tasks_response.json

if %errorlevel% equ 0 (
    echo ✅ 任务API测试成功
    echo 返回任务数量:
    findstr /c:"title" temp_tasks_response.json | find /c /v ""
) else (
    echo ❌ 任务API测试失败
)

echo.
echo 测试日志API...
curl -H "Authorization: Bearer %TOKEN%" ^
http://localhost:8080/api/logs ^
-s > temp_logs_response.json

if %errorlevel% equ 0 (
    echo ✅ 日志API测试成功
    echo 返回日志数量:
    findstr /c:"action" temp_logs_response.json | find /c /v ""
) else (
    echo ❌ 日志API测试失败
)

echo.
echo 4. 清理临时文件...
del temp_*.json 2>nul

echo.
echo 测试完成！
echo.
echo 📱 Android端测试账户:
echo    管理员: admin / admin123
echo    创始人: founder1 / founder123
echo    部门总监: hr_head / hr123
echo    员工: hr_emp1 / hremp123
echo    访客: 直接点击访客登录
echo.
echo 🌐 访问地址:
echo    API接口: http://localhost:8080/api
echo    Web管理: http://localhost:8080/web_admin
echo.
pause
