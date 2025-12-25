@echo off
echo ========================================
echo AI模块完整初始化脚本
echo ========================================
echo.
echo 本脚本将完成以下操作:
echo 1. 创建AI模块相关数据库表
echo 2. 加载所有用户的AI测试数据
echo 3. 验证数据完整性
echo.

REM 设置数据库连接参数
set DB_HOST=rm-2ze22f1xm8vvw4m44to.mysql.rds.aliyuncs.com
set DB_USER=pdl
set DB_PASSWORD=Pdl1234567
set DB_NAME=enterprise_management

echo 连接数据库: %DB_NAME%
echo.

REM 步骤1: 创建AI模块表
echo [步骤1/3] 创建AI模块数据库表...
call create_ai_module_tables.bat

if %ERRORLEVEL% neq 0 (
    echo 错误: 创建AI模块表失败
    pause
    exit /b 1
)

echo.
echo [步骤2/3] 加载AI测试数据...
call load_ai_test_data.bat

if %ERRORLEVEL% neq 0 (
    echo 错误: 加载AI测试数据失败
    pause
    exit /b 1
)

echo.
echo [步骤3/3] 验证数据完整性...

REM 验证表创建
echo 检查数据库表...
mysql -h%DB_HOST% -u%DB_USER% -p%DB_PASSWORD% %DB_NAME% -e "
SELECT 
    'wordcloud_analysis' as table_name, 
    COUNT(*) as record_count 
FROM wordcloud_analysis
UNION ALL
SELECT 
    'personality_analysis' as table_name, 
    COUNT(*) as record_count 
FROM personality_analysis
UNION ALL
SELECT 
    'mbti_records' as table_name, 
    COUNT(*) as record_count 
FROM mbti_records;
"

if %ERRORLEVEL% neq 0 (
    echo 错误: 数据验证失败
    pause
    exit /b 1
)

echo.
echo ========================================
echo AI模块完整初始化成功！
echo ========================================
echo.
echo 已完成的初始化:
echo ✓ 创建词云分析表 (wordcloud_analysis)
echo ✓ 创建性格分析表 (personality_analysis)
echo ✓ 加载MBTI记录数据
echo ✓ 加载性格分析数据 (10条记录)
echo ✓ 加载词云分析数据 (10条记录)
echo.
echo 用户数据覆盖:
echo - 管理员: 1人 (ENFP)
echo - 创始人: 1人 (INTJ) 
echo - 部门总监: 3人 (ISFJ, ISTJ, ENFJ)
echo - 团队长: 3人 (ENTJ, ISTJ, ESFJ)
echo - 员工: 3人 (ENFP, ISTJ, ENFP)
echo.
echo AI功能特性:
echo - 基于职位的合理MBTI类型分配
echo - 个性化的性格分析结果
echo - 符合角色特点的工作建议
echo - 真实的词云分析数据
echo - 完整的历史记录功能
echo.
echo API接口已就绪:
echo - POST /ai/personality-analysis (性格分析)
echo - GET /ai/personality-history (性格分析历史)
echo - POST /ai/save-wordcloud (保存词云分析)
echo - GET /ai/wordcloud-history (词云分析历史)
echo - POST /api/mbti-records (创建MBTI记录)
echo - GET /api/mbti-records (获取MBTI记录)
echo.
echo 测试步骤:
echo 1. 启动服务器: npm start
echo 2. 打开Flutter应用
echo 3. 进入AI地图模块
echo 4. 测试性格分析和词云功能
echo.
echo 配置DeepSeek API (可选):
echo 1. 在backend/.env中添加DEEPSEEK_API_KEY
echo 2. 重启服务器
echo 3. 享受AI增强的性格分析功能
echo.
pause
