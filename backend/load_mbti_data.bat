@echo off
echo 正在加载MBTI测试数据...

REM 设置数据库连接参数
set DB_HOST=localhost
set DB_USER=root
set DB_PASSWORD=hyx123456
set DB_NAME=enterprise_management

echo 连接数据库: %DB_NAME%

REM 执行MBTI表创建脚本
echo 创建MBTI记录表...
mysql -h%DB_HOST% -u%DB_USER% -p%DB_PASSWORD% %DB_NAME% < mbti_records_table.sql

if %ERRORLEVEL% neq 0 (
    echo 错误: 创建MBTI表失败
    pause
    exit /b 1
)

REM 执行MBTI测试数据插入脚本
echo 插入MBTI测试数据...
mysql -h%DB_HOST% -u%DB_USER% -p%DB_PASSWORD% %DB_NAME% < mbti_test_data.sql

if %ERRORLEVEL% neq 0 (
    echo 错误: 插入MBTI测试数据失败
    pause
    exit /b 1
)

echo.
echo ========================================
echo MBTI数据加载完成！
echo ========================================
echo.
echo 已创建的功能:
echo - MBTI记录表 (mbti_records)
echo - MBTI统计视图 (mbti_statistics)
echo - 用户MBTI历史视图 (user_mbti_history)
echo - 示例测试数据 (5条记录)
echo.
echo API接口:
echo - POST /api/mbti-records (创建记录)
echo - GET /api/mbti-records (获取列表)
echo - GET /api/mbti-records/:id (获取详情)
echo - PUT /api/mbti-records/:id (更新记录)
echo - DELETE /api/mbti-records/:id (删除记录)
echo - GET /api/mbti-records/statistics (统计信息)
echo.
echo AI模块相关:
echo - 运行 create_ai_module_tables.bat 创建AI分析表
echo - 运行 load_ai_test_data.bat 加载AI测试数据
echo.
echo 测试账户:
echo - 管理员: admin / admin123 (INFP)
echo - 创始人: founder1 / founder123 (INTJ)
echo - 人事总监: hr_head / hr123 (ESTJ)
echo - 财务总监: finance_head / finance123 (ISTJ)
echo - 宣传总监: marketing_head / marketing123 (ENFJ)
echo.
echo 下一步:
echo 1. 运行 create_ai_module_tables.bat
echo 2. 运行 load_ai_test_data.bat
echo 3. 启动服务器测试完整AI功能
echo.
pause
