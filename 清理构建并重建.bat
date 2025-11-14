@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo 清理构建缓存并重建 Android 项目
echo ========================================
echo.

:: 检查 Flutter 是否安装
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 未找到 Flutter，请确保 Flutter 已安装并在 PATH 中
    pause
    exit /b 1
)

echo [1/8] 清理 Flutter build 文件夹...
if exist "build" (
    echo 删除 build 文件夹...
    rmdir /s /q "build" 2>nul
    if exist "build" (
        echo ⚠ 警告: build 文件夹删除失败，可能被占用
    ) else (
        echo ✓ Flutter build 文件夹已删除
    )
) else (
    echo - build 文件夹不存在，跳过
)
echo.

echo [2/8] 清理 Android app build 文件夹...
if exist "android\app\build" (
    echo 删除 android\app\build 文件夹...
    rmdir /s /q "android\app\build" 2>nul
    if exist "android\app\build" (
        echo ⚠ 警告: android\app\build 文件夹删除失败，可能被占用
    ) else (
        echo ✓ Android app build 文件夹已删除
    )
) else (
    echo - android\app\build 文件夹不存在，跳过
)
echo.

echo [3/8] 清理 Android 项目 build 文件夹...
if exist "android\build" (
    echo 删除 android\build 文件夹...
    rmdir /s /q "android\build" 2>nul
    if exist "android\build" (
        echo ⚠ 警告: android\build 文件夹删除失败，可能被占用
    ) else (
        echo ✓ Android build 文件夹已删除
    )
) else (
    echo - android\build 文件夹不存在，跳过
)
echo.

echo [4/8] 清理 Android .gradle 缓存...
cd android
if exist ".gradle" (
    echo 删除 .gradle 文件夹...
    rmdir /s /q ".gradle" 2>nul
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

echo [5/8] 清理 Flutter .dart_tool 文件夹...
if exist ".dart_tool" (
    echo 删除 .dart_tool 文件夹...
    rmdir /s /q ".dart_tool" 2>nul
    if exist ".dart_tool" (
        echo ⚠ 警告: .dart_tool 文件夹删除失败，可能被占用
    ) else (
        echo ✓ .dart_tool 文件夹已删除
    )
) else (
    echo - .dart_tool 文件夹不存在，跳过
)
echo.

echo [6/8] 执行 Flutter clean...
flutter clean
if %errorlevel% equ 0 (
    echo ✓ Flutter clean 成功
) else (
    echo ⚠ 警告: Flutter clean 失败，继续执行...
)
echo.

echo [7/8] 清理 Flutter 插件缓存...
if exist ".flutter-plugins" del /q ".flutter-plugins" 2>nul
if exist ".flutter-plugins-dependencies" del /q ".flutter-plugins-dependencies" 2>nul
if exist ".packages" del /q ".packages" 2>nul
echo ✓ Flutter 插件缓存已清理
echo.

echo [8/8] 获取 Flutter 依赖...
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
echo 清理完成！
echo ========================================
echo.
echo 建议的下一步操作：
echo.
echo 1. 重新构建项目：
echo    flutter build apk --debug
echo.
echo 2. 或直接运行：
echo    flutter run
echo.
echo 3. 如果仍然有问题，可以尝试：
echo    cd android
echo    gradlew clean
echo    cd ..
echo    flutter build apk --debug
echo.
pause

