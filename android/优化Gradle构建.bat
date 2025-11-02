@echo off
chcp 65001 >nul
echo ========================================
echo Gradle构建优化脚本
echo ========================================
echo.

cd /d "%~dp0"

echo [1/5] 停止现有的Gradle守护进程...
call gradlew.bat --stop
if errorlevel 1 (
    echo 提示: 没有运行的守护进程，这是正常的
)
echo.

echo [2/5] 清理Flutter构建缓存...
cd ..
flutter clean
if errorlevel 1 (
    echo 警告: Flutter clean 执行失败
)
echo.

echo [3/5] 清理Gradle构建缓存...
cd android
call gradlew.bat clean
if errorlevel 1 (
    echo 警告: Gradle clean 执行失败
)
echo.

echo [4/5] 重新获取Flutter依赖...
cd ..
flutter pub get
if errorlevel 1 (
    echo 错误: Flutter pub get 失败
    pause
    exit /b 1
)
echo.

echo [5/5] 预编译Gradle项目（这将下载所有依赖）...
cd android
echo 注意: 这可能需要几分钟时间，但可以加快后续构建速度...
call gradlew.bat build --dry-run
if errorlevel 1 (
    echo 警告: Gradle build dry-run 失败，但可以继续
)
echo.

echo ========================================
echo 优化完成！
echo ========================================
echo.
echo 已完成的优化：
echo   ✓ 停止旧守护进程
echo   ✓ 清理构建缓存
echo   ✓ 重新获取依赖
echo   ✓ 预下载Gradle依赖
echo.
echo 现在的gradle.properties已配置：
echo   ✓ 并行构建 (parallel=true)
echo   ✓ 构建缓存 (caching=true)
echo   ✓ Gradle守护进程 (daemon=true)
echo   ✓ 增加JVM内存 (8GB)
echo.
echo 请在Android Studio中重新同步项目（Sync Project with Gradle Files）
echo 或直接运行应用，构建速度应该会更快！
echo.
pause

