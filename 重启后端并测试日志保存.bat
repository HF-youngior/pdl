@echo off
chcp 65001 >nul
echo ========================================
echo 重启后端并测试日志保存
echo ========================================
echo.

echo [1/3] 停止现有后端服务...
taskkill /F /FI "WINDOWTITLE eq *backend*" 2>nul
taskkill /F /IM node.exe /FI "WINDOWTITLE eq *backend*" 2>nul
timeout /t 2 >nul
echo 已停止
echo.

echo [2/3] 启动后端服务...
cd backend
start "后端服务" cmd /k "node server_enterprise.js"
cd ..
echo 后端已启动
echo.

echo [3/3] 等待后端启动...
timeout /t 5 >nul
echo.

echo ========================================
echo 修复完成！
echo ========================================
echo.
echo 已修复内容：
echo 1. 删除了 personal_logs 表中的重复字段定义
echo 2. 修复了 ensureSchemaCompatibility 函数，移除 IF NOT EXISTS
echo.
echo 如果数据库中仍缺少 log_date 字段，后端启动时会自动添加。
echo 请现在尝试保存日志，应该不会再报错。
echo.
echo 如果还有问题，请检查后端控制台的错误信息。
echo.
pause

