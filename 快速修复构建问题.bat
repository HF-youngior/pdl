@echo off
chcp 65001 >nul
echo ========================================
echo 快速修复 Gradle 构建问题
echo ========================================
echo.
echo 此脚本将执行以下操作：
echo 1. 停止 Gradle 守护进程
echo 2. 清理构建缓存
echo 3. 重新构建项目
echo.
pause

:: 检查 Flutter 是否安装
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 未找到 Flutter，请确保 Flutter 已安装并在 PATH 中
    pause
    exit /b 1
)

echo.
echo [1/4] 停止 Gradle 守护进程...
cd android
call gradlew.bat --stop 2>nul
if %errorlevel% equ 0 (
    echo ✓ Gradle 守护进程已停止
) else (
    echo - Gradle 守护进程未运行或已停止
)
cd ..
echo.

echo [2/4] 清理构建缓存...
if exist "build" rmdir /s /q "build" 2>nul
if exist "android\app\build" rmdir /s /q "android\app\build" 2>nul
if exist "android\build" rmdir /s /q "android\build" 2>nul
if exist "android\.gradle" rmdir /s /q "android\.gradle" 2>nul
if exist ".dart_tool" rmdir /s /q ".dart_tool" 2>nul
echo ✓ 构建缓存已清理
echo.

echo [3/4] 执行 Flutter clean 和 pub get...
flutter clean
flutter pub get
if %errorlevel% neq 0 (
    echo ✗ Flutter pub get 失败
    pause
    exit /b 1
)
echo ✓ Flutter 依赖已获取
echo.

echo [4/4] 重新构建项目...
echo.
echo 正在构建 APK，请稍候...
flutter build apk --debug
if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo ✓ 构建成功！
    echo ========================================
    echo.
    echo APK 文件位置：
    echo   android\app\build\outputs\apk\debug\app-debug.apk
    echo   android\app\build\outputs\flutter-apk\app-debug.apk
    echo.
) else (
    echo.
    echo ========================================
    echo ✗ 构建失败
    echo ========================================
    echo.
    echo 请尝试运行：彻底清理构建缓存.bat
    echo 或查看：Gradle构建问题解决方案.md
    echo.
)
echo.
pause

