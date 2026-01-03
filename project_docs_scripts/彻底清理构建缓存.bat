@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo 彻底清理构建缓存（包括 Gradle 守护进程）
echo ========================================
echo.
echo 警告: 此脚本将清理所有构建缓存，包括 Gradle 缓存
echo 这可能需要重新下载依赖，请确保网络连接正常
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
echo [1/10] 停止 Gradle 守护进程...
cd android
call gradlew.bat --stop 2>nul
if %errorlevel% equ 0 (
    echo ✓ Gradle 守护进程已停止
) else (
    echo - Gradle 守护进程未运行或已停止
)
cd ..
echo.

echo [2/10] 清理 Flutter build 文件夹...
if exist "build" (
    echo 删除 build 文件夹...
    rmdir /s /q "build" 2>nul
    timeout /t 1 >nul
    if exist "build" (
        echo ⚠ 警告: build 文件夹删除失败，可能被占用
        echo 请关闭所有可能占用该文件夹的程序（如 Android Studio、VS Code 等）
    ) else (
        echo ✓ Flutter build 文件夹已删除
    )
) else (
    echo - build 文件夹不存在，跳过
)
echo.

echo [3/10] 清理 Android app build 文件夹...
if exist "android\app\build" (
    echo 删除 android\app\build 文件夹...
    rmdir /s /q "android\app\build" 2>nul
    timeout /t 1 >nul
    if exist "android\app\build" (
        echo ⚠ 警告: android\app\build 文件夹删除失败，可能被占用
    ) else (
        echo ✓ Android app build 文件夹已删除
    )
) else (
    echo - android\app\build 文件夹不存在，跳过
)
echo.

echo [4/10] 清理 Android 项目 build 文件夹...
if exist "android\build" (
    echo 删除 android\build 文件夹...
    rmdir /s /q "android\build" 2>nul
    timeout /t 1 >nul
    if exist "android\build" (
        echo ⚠ 警告: android\build 文件夹删除失败，可能被占用
    ) else (
        echo ✓ Android build 文件夹已删除
    )
) else (
    echo - android\build 文件夹不存在，跳过
)
echo.

echo [5/10] 清理 Android .gradle 缓存...
cd android
if exist ".gradle" (
    echo 删除 .gradle 文件夹...
    rmdir /s /q ".gradle" 2>nul
    timeout /t 1 >nul
    if exist ".gradle" (
        echo ⚠ 警告: .gradle 文件夹删除失败，可能被占用
    ) else (
        echo ✓ .gradle 文件夹已删除
    )
) else (
    echo - .gradle 文件夹不存在，跳过
)
cd ..
echo.

echo [6/10] 清理 Flutter .dart_tool 文件夹...
if exist ".dart_tool" (
    echo 删除 .dart_tool 文件夹...
    rmdir /s /q ".dart_tool" 2>nul
    timeout /t 1 >nul
    if exist ".dart_tool" (
        echo ⚠ 警告: .dart_tool 文件夹删除失败，可能被占用
    ) else (
        echo ✓ .dart_tool 文件夹已删除
    )
) else (
    echo - .dart_tool 文件夹不存在，跳过
)
echo.

echo [7/10] 清理 Flutter 插件缓存文件...
if exist ".flutter-plugins" (
    del /q ".flutter-plugins" 2>nul
    echo ✓ .flutter-plugins 已删除
)
if exist ".flutter-plugins-dependencies" (
    del /q ".flutter-plugins-dependencies" 2>nul
    echo ✓ .flutter-plugins-dependencies 已删除
)
if exist ".packages" (
    del /q ".packages" 2>nul
    echo ✓ .packages 已删除
)
echo.

echo [8/10] 执行 Flutter clean...
flutter clean
if %errorlevel% equ 0 (
    echo ✓ Flutter clean 成功
) else (
    echo ⚠ 警告: Flutter clean 失败，继续执行...
)
echo.

echo [9/10] 执行 Gradle clean...
cd android
call gradlew.bat clean 2>nul
if %errorlevel% equ 0 (
    echo ✓ Gradle clean 成功
) else (
    echo ⚠ 警告: Gradle clean 失败，可能正常（如果 build 文件夹已删除）
)
cd ..
echo.

echo [10/10] 获取 Flutter 依赖...
flutter pub get
if %errorlevel% equ 0 (
    echo ✓ Flutter pub get 成功
) else (
    echo ✗ Flutter pub get 失败
    echo.
    echo 请检查网络连接和 pubspec.yaml 配置
    pause
    exit /b 1
)
echo.

echo ========================================
echo 彻底清理完成！
echo ========================================
echo.
echo 建议的下一步操作：
echo.
echo 1. 重新构建项目（推荐）：
echo    flutter build apk --debug
echo.
echo 2. 或直接运行：
echo    flutter run
echo.
echo 3. 如果仍然有问题，可以尝试：
echo    cd android
echo    gradlew clean build
echo    cd ..
echo    flutter build apk --debug
echo.
echo 4. 如果问题持续，请检查：
echo    - Android SDK 是否正确安装
echo    - local.properties 中的路径是否正确
echo    - Gradle 版本是否兼容
echo.
pause

