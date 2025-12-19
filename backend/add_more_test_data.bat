@echo off
setlocal ENABLEDELAYEDEXPANSION
chcp 65001 >nul

:: ================================================
:: 企业管理系统 - 数据增强脚本
:: 说明：为已有数据库添加更多测试数据
:: 前提：数据库已通过 init_all_data.bat 初始化
:: ================================================

:: 可配置参数
set DB_HOST=rm-2ze22f1xm8vvw4m44to.mysql.rds.aliyuncs.com
set DB_PORT=3306
set DB_USER=pdl
set DB_PASSWORD=Pdl1234567
set SCRIPT_DIR=%~dp0

:: 连接字符串
set MYSQL_BASE=mysql -h %DB_HOST% -P %DB_PORT% -u %DB_USER% -p%DB_PASSWORD% --default-character-set=utf8mb4 --protocol=tcp

:: 显示环境信息
echo ================================================
echo 数据增强脚本
echo ================================================
echo   Host: %DB_HOST%
echo   User: %DB_USER%
echo   Database: enterprise_management
echo ================================================
echo.

:: 检查数据库是否存在
echo 检查数据库连接...
%MYSQL_BASE% -e "USE enterprise_management;" >nul 2>&1
if errorlevel 1 (
  echo [错误] 无法连接到数据库，请先运行 init_all_data.bat 初始化数据库
  pause
  exit /b 1
)

:: 定义要加载的数据文件（可选的增强数据）
set "DATA_FILES[0]=load_more_test_data.sql"
set "DATA_FILES[1]=add_hr_head_monthly_tasks.sql"
set "DATA_FILES[2]=insert_hr_head_rich_logs.sql"
set "DATA_FILES[3]=rich_hr_data_oct_nov_2025.sql"

:: 询问用户要加载哪些数据
echo 请选择要加载的增强数据：
echo.
echo 1. 基础增强数据（推荐）
echo 2. HR总监月度任务数据
echo 3. HR总监丰富日志数据
echo 4. HR总监10-11月数据
echo 5. 加载所有增强数据
echo 6. 退出
echo.

set /p choice="请输入选项 (1-6): "

if "%choice%"=="1" goto :load_basic
if "%choice%"=="2" goto :load_monthly_tasks
if "%choice%"=="3" goto :load_rich_logs
if "%choice%"=="4" goto :load_oct_nov
if "%choice%"=="5" goto :load_all
if "%choice%"=="6" exit /b 0

echo 无效选项，退出
pause
exit /b 1

:load_basic
echo.
echo [选择1] 加载基础增强数据...
if exist "%SCRIPT_DIR%add_more_test_data.sql" (
  %MYSQL_BASE% enterprise_management < "%SCRIPT_DIR%add_more_test_data.sql"
  if errorlevel 1 (
    echo [警告] 基础增强数据加载失败
  ) else (
    echo ✓ 基础增强数据加载成功
  )
) else (
  echo [跳过] 未找到 add_more_test_data.sql
)
goto :end

:load_monthly_tasks
echo.
echo [选择2] 加载HR总监月度任务数据...
if exist "%SCRIPT_DIR%add_hr_head_monthly_tasks.sql" (
  %MYSQL_BASE% enterprise_management < "%SCRIPT_DIR%add_hr_head_monthly_tasks.sql"
  if errorlevel 1 (
    echo [警告] HR月度任务数据加载失败
  ) else (
    echo ✓ HR月度任务数据加载成功
  )
) else (
  echo [跳过] 未找到 add_hr_head_monthly_tasks.sql
)
goto :end

:load_rich_logs
echo.
echo [选择3] 加载HR总监丰富日志数据...
if exist "%SCRIPT_DIR%insert_hr_head_rich_logs.sql" (
  %MYSQL_BASE% enterprise_management < "%SCRIPT_DIR%insert_hr_head_rich_logs.sql"
  if errorlevel 1 (
    echo [警告] HR丰富日志数据加载失败
  ) else (
    echo ✓ HR丰富日志数据加载成功
  )
) else (
  echo [跳过] 未找到 insert_hr_head_rich_logs.sql
)
goto :end

:load_oct_nov
echo.
echo [选择4] 加载HR总监10-11月数据...
if exist "%SCRIPT_DIR%rich_hr_data_oct_nov_2025.sql" (
  %MYSQL_BASE% enterprise_management < "%SCRIPT_DIR%rich_hr_data_oct_nov_2025.sql"
  if errorlevel 1 (
    echo [警告] HR 10-11月数据加载失败
  ) else (
    echo ✓ HR 10-11月数据加载成功
  )
) else (
  echo [跳过] 未找到 rich_hr_data_oct_nov_2025.sql
)
goto :end

:load_all
echo.
echo [选择5] 加载所有增强数据...
set loaded_count=0

if exist "%SCRIPT_DIR%add_more_test_data.sql" (
  echo 加载基础增强数据...
  %MYSQL_BASE% enterprise_management < "%SCRIPT_DIR%add_more_test_data.sql"
  if not errorlevel 1 set /a loaded_count+=1
)

if exist "%SCRIPT_DIR%add_hr_head_monthly_tasks.sql" (
  echo 加载HR月度任务...
  %MYSQL_BASE% enterprise_management < "%SCRIPT_DIR%add_hr_head_monthly_tasks.sql"
  if not errorlevel 1 set /a loaded_count+=1
)

if exist "%SCRIPT_DIR%insert_hr_head_rich_logs.sql" (
  echo 加载HR丰富日志...
  %MYSQL_BASE% enterprise_management < "%SCRIPT_DIR%insert_hr_head_rich_logs.sql"
  if not errorlevel 1 set /a loaded_count+=1
)

if exist "%SCRIPT_DIR%rich_hr_data_oct_nov_2025.sql" (
  echo 加载HR 10-11月数据...
  %MYSQL_BASE% enterprise_management < "%SCRIPT_DIR%rich_hr_data_oct_nov_2025.sql"
  if not errorlevel 1 set /a loaded_count+=1
)

echo.
echo ✓ 共加载 !loaded_count! 项增强数据
goto :end

:end
echo.
echo ================================================
echo 数据增强完成
echo ================================================
echo.
echo 提示：
echo   • 如需重新初始化数据库，请运行: init_all_data.bat
echo   • 如需更新任务描述，请运行: update_all_hr_descriptions.bat
echo   • 如需更新MBTI数据，请运行: update_mbti_data.bat
echo.
pause
exit /b 0

