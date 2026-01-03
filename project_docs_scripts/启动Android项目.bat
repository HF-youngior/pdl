@echo off
echo 企业管理系统 - Android项目启动助手
echo ======================================

echo.
echo 正在检查项目配置...

echo.
echo 1. 检查Flutter依赖...
cd /d "%~dp0"
flutter pub get

echo.
echo 2. 检查Android配置...
if not exist "android\app\build.gradle.kts" (
    echo 错误：找不到Android配置文件
    pause
    exit /b 1
)

echo.
echo 3. 项目配置完成！
echo.
echo 现在您可以：
echo.
echo 1. 启动后端服务器：
echo    - 双击运行 start_backend.bat
echo    - 或手动执行：cd backend ^&^& npm start
echo.
echo 2. 在Android Studio中打开项目：
echo    - 打开Android Studio
echo    - 选择 "Open an existing Android Studio project"
echo    - 选择 android 文件夹
echo    - 等待同步完成
echo    - 点击运行按钮
echo.
echo 3. 测试账户：
echo    - 管理员: admin / admin123
echo    - 部门老总: manager / manager123
echo    - 普通员工: employee1 / employee123
echo.

echo 按任意键打开Android Studio...
pause

echo.
echo 正在尝试打开Android Studio...
start "" "android"

echo.
echo 如果Android Studio没有自动打开，请手动打开并选择android文件夹
echo.
pause
