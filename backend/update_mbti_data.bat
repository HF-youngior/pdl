@echo off
echo ========================================
echo 更新MBTI数据脚本
echo ========================================
echo.
echo 本脚本将更新admin和hr_head的MBTI数据:
echo - admin: ENFP -> INFP
echo - hr_head: ISFJ -> ESTJ
echo.

REM 设置数据库连接参数
set DB_HOST=rm-2zeoa1b89ga70ikpifo.mysql.rds.aliyuncs.com
set DB_USER=pdl123
set DB_PASSWORD=Pdl1234567
set DB_NAME=enterprise_management

echo 连接数据库: %DB_NAME%

REM 删除现有的MBTI记录
echo 删除现有MBTI记录...
mysql -h%DB_HOST% -u%DB_USER% -p%DB_PASSWORD% %DB_NAME% -e "
DELETE FROM mbti_records WHERE user_id IN ('admin-001', 'hr_head');
"

if %ERRORLEVEL% neq 0 (
    echo 错误: 删除现有MBTI记录失败
    pause
    exit /b 1
)

REM 重新插入更新的MBTI数据
echo 插入更新的MBTI数据...
mysql -h%DB_HOST% -u%DB_USER% -p%DB_PASSWORD% %DB_NAME% < mbti_test_data.sql

if %ERRORLEVEL% neq 0 (
    echo 错误: 插入MBTI数据失败
    pause
    exit /b 1
)

REM 验证数据
echo 验证更新结果...
mysql -h%DB_HOST% -u%DB_USER% -p%DB_PASSWORD% %DB_NAME% -e "
SELECT 
    user_id,
    mbti_type,
    JSON_EXTRACT(test_scores, '$.I') as I_score,
    JSON_EXTRACT(test_scores, '$.E') as E_score,
    JSON_EXTRACT(test_scores, '$.S') as S_score,
    JSON_EXTRACT(test_scores, '$.N') as N_score,
    JSON_EXTRACT(test_scores, '$.T') as T_score,
    JSON_EXTRACT(test_scores, '$.F') as F_score,
    JSON_EXTRACT(test_scores, '$.J') as J_score,
    JSON_EXTRACT(test_scores, '$.P') as P_score
FROM mbti_records 
WHERE user_id IN ('admin-001', 'hr_head')
ORDER BY user_id;
"

echo.
echo ========================================
echo MBTI数据更新完成！
echo ========================================
echo.
echo 更新结果:
echo - admin-001: INFP (内向、直觉、情感、感知)
echo - hr_head: ESTJ (外向、感觉、思维、判断)
echo.
echo 下一步: 测试AI性格分析功能
echo.
pause

