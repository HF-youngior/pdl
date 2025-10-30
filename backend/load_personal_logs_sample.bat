@echo off
chcp 65001 >nul
echo 加载个人日志样例数据...
echo.

REM Set database connection parameters
set DB_HOST=localhost
set DB_USER=root
set DB_PASSWORD=Zs462581379
set DB_NAME=enterprise_management
set DB_PORT=3306

echo 正在加载个人日志样例数据...
mysql -h%DB_HOST% -P%DB_PORT% -u%DB_USER% -p%DB_PASSWORD% %DB_NAME% < migrations/2025-10-sample-personal-logs.sql

if %errorlevel% neq 0 (
    echo Error: Failed to load personal logs sample data
    pause
    exit /b 1
)

echo 个人日志样例数据加载成功！
echo.
echo 新增数据包括:
echo - 12条个人日志记录（包含背锅、汇报、疲惫等关键词）
echo - 对应的任务关联数据
echo - 多样化的天气、日期、分类信息
echo.
echo 现在可以在应用中看到这些样例数据了！
echo.
pause
