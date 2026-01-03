@echo off
chcp 65001 >nul
echo ========================================
echo 修复Dart SDK更新失败问题
echo ========================================
echo.

echo [1/6] 停止所有Flutter和Gradle进程...
taskkill /F /IM flutter.exe 2>nul
taskkill /F /IM dart.exe 2>nul
taskkill /F /IM java.exe 2>nul
timeout /t 2 >nul
echo 进程已停止
echo.

echo [2/6] 停止Gradle守护进程...
cd android
if exist gradlew.bat (
    call gradlew.bat --stop 2>nul
)
cd ..
echo.

echo [3/6] 检查Flutter SDK路径...
if not defined FLUTTER_ROOT (
    echo 错误: 未找到FLUTTER_ROOT环境变量
    echo 请确保Flutter已正确安装并配置环境变量
    pause
    exit /b 1
)

set "FLUTTER_PATH=%FLUTTER_ROOT%"
if not exist "%FLUTTER_PATH%\bin\flutter.bat" (
    echo 错误: 在 %FLUTTER_PATH% 找不到Flutter
    echo 请检查Flutter SDK路径是否正确
    pause
    exit /b 1
)
echo Flutter路径: %FLUTTER_PATH%
echo.

echo [4/6] 清理Dart SDK缓存（需要关闭Android Studio）...
echo 警告: 此步骤需要关闭Android Studio和所有相关进程！
echo 如果Android Studio正在运行，请先关闭它
echo.
pause

set "DART_SDK_PATH=%FLUTTER_PATH%\bin\cache\dart-sdk"
if exist "%DART_SDK_PATH%" (
    echo 正在清理旧的Dart SDK...
    rmdir /S /Q "%DART_SDK_PATH%" 2>nul
    if errorlevel 1 (
        echo 警告: 无法删除Dart SDK，可能被占用
        echo 请手动关闭所有使用Flutter/Dart的程序后重试
    ) else (
        echo Dart SDK缓存已清理
    )
)
echo.

echo [5/6] 清理Flutter构建缓存...
cd /d "%~dp0"
flutter clean
if errorlevel 1 (
    echo 警告: Flutter clean 执行失败
)
echo.

echo [6/7] 验证Dart SDK版本（不升级，保持当前版本）...
flutter --version
if errorlevel 1 (
    echo 警告: Flutter版本检查失败
)
echo.

echo [7/7] 重新获取Flutter依赖（不升级Dart SDK）...
set "FLUTTER_CHANNEL=stable"
flutter pub get --no-upgrade
if errorlevel 1 (
    echo 尝试使用默认方式...
    flutter pub get
    if errorlevel 1 (
        echo 错误: Flutter pub get 失败
        pause
        exit /b 1
    )
)

echo.
echo ========================================
echo 修复完成！
echo ========================================
echo.
echo 请按照以下步骤操作：
echo.
echo 1. 确保Android Studio已完全关闭
echo 2. 重新打开Android Studio
echo 3. 打开项目并点击 "Sync Project with Gradle Files"
echo 4. 如果还有问题，重启电脑后再试
echo.
pause

