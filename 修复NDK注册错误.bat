@echo off
chcp 65001 >nul
echo ========================================
echo 修复Android Studio NDK注册错误
echo ========================================
echo.

echo [1/5] 停止所有Gradle守护进程...
cd android
if exist gradlew.bat (
    call gradlew.bat --stop 2>nul
)
cd ..
echo 完成
echo.

echo [2/5] 删除.idea目录（IDE配置）...
if exist android\.idea (
    rmdir /S /Q android\.idea 2>nul
    if errorlevel 1 (
        echo 警告: 无法删除.idea目录，可能被IDE占用
        echo 请先关闭Android Studio
    ) else (
        echo .idea目录已清理
    )
)
if exist .idea (
    echo 提示: 项目根目录也有.idea，建议关闭IDE后手动清理
)
echo.

echo [3/5] 清理Flutter缓存...
flutter clean
echo.

echo [4/5] 重新获取Flutter依赖...
flutter pub get
echo.

echo [5/5] 清理Gradle缓存...
cd android
if exist gradlew.bat (
    call gradlew.bat clean
)
cd ..
echo.

echo ========================================
echo 修复完成！
echo ========================================
echo.
echo 请按照以下步骤操作：
echo.
echo 1. 完全关闭Android Studio
echo 2. 等待5秒后重新打开Android Studio
echo 3. 打开项目
echo 4. 等待自动同步完成（或点击 "Sync Project with Gradle Files"）
echo 5. 如果还有问题，请点击 File ^> Invalidate Caches / Restart
echo.
pause

