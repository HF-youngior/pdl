@echo off
chcp 65001 >nul
echo ========================================
echo 修复 Gradle 路径冲突问题
echo ========================================
echo.

echo [1/5] 停止 Gradle 守护进程...
cd android
if exist gradlew.bat (
    call gradlew.bat --stop
) else (
    echo 警告: 未找到 gradlew.bat
)
cd ..

echo.
echo [2/5] 清理 Flutter 构建缓存...
flutter clean

echo.
echo [3/5] 清理 Android 构建目录...
if exist build (
    echo 删除 build 目录...
    rmdir /s /q build
    echo build 目录已删除
) else (
    echo build 目录不存在，跳过
)

if exist android\build (
    echo 删除 android\build 目录...
    rmdir /s /q android\build
    echo android\build 目录已删除
) else (
    echo android\build 目录不存在，跳过
)

echo.
echo [4/5] 清理 Gradle 缓存...
if exist android\.gradle (
    echo 删除 android\.gradle 目录...
    rmdir /s /q android\.gradle
    echo android\.gradle 目录已删除
) else (
    echo android\.gradle 目录不存在，跳过
)

echo.
echo [5/5] 重新获取 Flutter 依赖...
flutter pub get

echo.
echo ========================================
echo 修复完成！
echo ========================================
echo.
echo 下一步操作：
echo 1. 在 Android Studio 中点击 "Sync Project with Gradle Files"
echo 2. 或者运行: cd android ^&^& gradlew.bat build
echo.
pause

