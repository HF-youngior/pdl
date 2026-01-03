@echo off
chcp 65001 >nul
echo ========================================
echo 使用 Gradle 直接构建 APK
echo ========================================
echo.

cd android
echo 正在构建 APK...
call gradlew.bat assembleDebug

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo ✓ 构建成功！
    echo ========================================
    echo.
    cd ..
    if exist "android\app\build\outputs\apk\debug\app-debug.apk" (
        echo APK 文件位置：
        echo   android\app\build\outputs\apk\debug\app-debug.apk
        echo.
        echo 文件信息：
        for %%F in ("android\app\build\outputs\apk\debug\app-debug.apk") do (
            echo   大小: %%~zF 字节
            echo   修改时间: %%~tF
        )
        echo.
    )
    if exist "android\app\build\outputs\flutter-apk\app-debug.apk" (
        echo APK 文件位置（Flutter）：
        echo   android\app\build\outputs\flutter-apk\app-debug.apk
        echo.
    )
) else (
    echo.
    echo ========================================
    echo ✗ 构建失败
    echo ========================================
    cd ..
)

echo.
pause

