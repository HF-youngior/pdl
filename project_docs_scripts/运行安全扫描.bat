@echo off
chcp 65001 >nul
echo ========================================
echo SonarQube 安全扫描工具
echo ========================================
echo.
echo 正在运行SonarQube安全扫描...
echo.

cd /d f:\pdl
"D:\sonar-scanner-4.8.0.2856\bin\sonar-scanner.bat" -X "-D sonar.login=sqp_5d7884ce3957f7c0f5449d1a8d5a9bd1ec355d49"

echo.
echo ========================================
echo 扫描完成！
echo.
echo 请访问以下地址查看扫描结果：
echo http://localhost:9000/dashboard?id=pdl_enterprise_backend
echo.
echo 按任意键打开扫描结果...
pause >nul
start http://localhost:9000/dashboard?id=pdl_enterprise_backend
echo.
echo 已在浏览器中打开扫描结果
echo ========================================
pause