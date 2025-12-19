@echo off
chcp 65001 >nul
echo 加载修复的增强示例数据 (版本2)...
echo.

REM Set database connection parameters
<<<<<<< Updated upstream
set DB_HOST=rm-2ze22f1xm8vvw4m44to.mysql.rds.aliyuncs.com
set DB_USER=pdl
set DB_PASSWORD=Pdl1234567
=======
set DB_HOST=localhost
set DB_USER=root
set DB_PASSWORD=Zs462581379
>>>>>>> Stashed changes
set DB_NAME=enterprise_management
set DB_PORT=3306

echo 正在加载修复的增强示例数据...
mysql -h%DB_HOST% -P%DB_PORT% -u%DB_USER% -p%DB_PASSWORD% %DB_NAME% < fixed_enhanced_data.sql

if %errorlevel% neq 0 (
    echo Error: Failed to load fixed enhanced sample data
    pause
    exit /b 1
)

echo 修复的增强示例数据加载成功！
echo.
echo 新增数据包括:
echo - 为每个角色添加了更多任务
echo - 添加了个人日志数据（修复了字段问题）
echo - 添加了系统日志数据
echo - 更新了任务进度（使用UPDATE语句）
echo - 使用INSERT IGNORE避免重复键错误
echo.
pause
